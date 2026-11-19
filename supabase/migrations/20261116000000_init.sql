-- =============================================================================
-- Lumin MVP — Schema inicial
-- Princípios:
--   * Toda escrita sensível (registro de cuidado, onboarding, convites) passa por
--     RPCs SECURITY DEFINER -> regras de domínio e concorrência ficam no servidor.
--   * "Dia" e "ofensiva" são sempre calculados no fuso do PET, nunca do celular.
--   * Registro de cuidado é idempotente: id gerado no cliente + UNIQUE por slot.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TABELAS
-- -----------------------------------------------------------------------------
create table public.households (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'Família' check (char_length(name) between 1 and 40),
  created_at  timestamptz not null default now()
);

create table public.household_members (
  household_id  uuid not null references public.households(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  role          text not null default 'member' check (role in ('owner','member','sitter')),
  display_name  text not null check (char_length(display_name) between 1 and 30),
  expires_at    timestamptz,                       -- obrigatório para 'sitter'
  joined_at     timestamptz not null default now(),
  primary key (household_id, user_id),
  check (role <> 'sitter' or expires_at is not null)
);
create index household_members_user_idx on public.household_members(user_id);

create table public.pets (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references public.households(id) on delete cascade,
  name          text not null check (char_length(name) between 1 and 30),
  species       text not null check (species in ('dog','cat')),
  timezone      text not null,                     -- IANA, ex: 'America/Sao_Paulo'
  avatar_dna    jsonb not null check (avatar_dna ? 'v'),
  created_at    timestamptz not null default now()
);
create index pets_household_idx on public.pets(household_id);

create table public.care_tasks (
  id             uuid primary key default gen_random_uuid(),
  pet_id         uuid not null references public.pets(id) on delete cascade,
  type           text not null check (type in ('feed','walk','medication','flea_tick','deworm','custom')),
  label          text check (label is null or char_length(label) between 1 and 40),
  kind           text not null check (kind in ('daily','interval')),
  daily_times    time[],                           -- kind='daily': horários dos slots
  interval_days  int,                              -- kind='interval': ex. 30 (antipulgas)
  next_due_date  date,                             -- kind='interval'
  active         boolean not null default true,
  created_at     timestamptz not null default now(),
  constraint care_tasks_schedule_chk check (
    (kind = 'daily' and daily_times is not null and cardinality(daily_times) between 1 and 6
       and interval_days is null and next_due_date is null)
    or
    (kind = 'interval' and interval_days between 1 and 365 and next_due_date is not null
       and daily_times is null)
  )
);
create index care_tasks_pet_active_idx on public.care_tasks(pet_id) where active;

create table public.care_logs (
  id                  uuid primary key,            -- gerado no CLIENTE (idempotência offline)
  task_id             uuid not null references public.care_tasks(id) on delete cascade,
  pet_id              uuid not null references public.pets(id) on delete cascade,
  slot_date           date not null,               -- data LOCAL do pet
  slot_index          smallint not null default 0 check (slot_index between 0 and 5),
  done_by             uuid references auth.users(id) on delete set null,
  occurred_at         timestamptz not null,
  prev_next_due_date  date,                        -- permite "desfazer" em tarefas de intervalo
  created_at          timestamptz not null default now(),
  constraint care_logs_slot_uniq unique (task_id, slot_date, slot_index)
);
create index care_logs_pet_date_idx on public.care_logs(pet_id, slot_date desc);

-- Dias "fechados" do pet: base para a ofensiva (gaps-and-islands)
create table public.pet_days (
  pet_id      uuid not null references public.pets(id) on delete cascade,
  local_date  date not null,
  status      text not null check (status in ('complete','frozen')),
  primary key (pet_id, local_date)
);

create table public.pet_streaks (
  pet_id        uuid primary key references public.pets(id) on delete cascade,
  longest_days  int not null default 0,
  freezes       int not null default 1 check (freezes between 0 and 3),
  updated_at    timestamptz not null default now()
);

create table public.household_invites (
  code          text primary key check (code ~ '^[A-Z2-9]{6}$'),
  household_id  uuid not null references public.households(id) on delete cascade,
  created_by    uuid not null references auth.users(id) on delete cascade,
  role          text not null default 'member' check (role in ('member','sitter')),
  sitter_days   int check (sitter_days between 1 and 30),
  expires_at    timestamptz not null default now() + interval '7 days',
  max_uses      int not null default 5,
  uses          int not null default 0,
  check (role <> 'sitter' or sitter_days is not null)
);

create table public.push_tokens (
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  token       text not null,
  platform    text not null check (platform in ('ios','android')),
  updated_at  timestamptz not null default now(),
  primary key (user_id, token)
);

-- -----------------------------------------------------------------------------
-- HELPERS DE AUTORIZAÇÃO
-- -----------------------------------------------------------------------------
create or replace function public.is_member(p_household uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from household_members
    where household_id = p_household and user_id = auth.uid()
      and (expires_at is null or expires_at > now())
  );
$$;

create or replace function public.is_editor(p_household uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from household_members
    where household_id = p_household and user_id = auth.uid()
      and role in ('owner','member')
  );
$$;

create or replace function public.can_access_pet(p_pet uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from pets p where p.id = p_pet and is_member(p.household_id));
$$;

create or replace function public.can_edit_pet(p_pet uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from pets p where p.id = p_pet and is_editor(p.household_id));
$$;

-- -----------------------------------------------------------------------------
-- OFENSIVA
-- -----------------------------------------------------------------------------
-- Ofensiva atual = dias 'complete' da última ilha contínua (frozen mantém a ilha
-- viva mas não soma), desde que a ilha termine hoje ou ontem (fuso do pet).
create or replace function public.pet_streak(p_pet uuid)
returns int language sql stable security definer set search_path = public as $$
  with tz as (
    select (now() at time zone timezone)::date as today
    from pets where id = p_pet and is_member(household_id)
  ),
  d as (
    select pd.local_date, pd.status,
           pd.local_date - (row_number() over (order by pd.local_date))::int as grp
    from pet_days pd, tz
    where pd.pet_id = p_pet and pd.local_date <= tz.today
  ),
  islands as (
    select grp, max(local_date) as last_day,
           count(*) filter (where status = 'complete') as days
    from d group by grp
  )
  select coalesce((
    select case when i.last_day >= tz.today - 1 then i.days::int else 0 end
    from islands i, tz order by i.last_day desc limit 1
  ), 0);
$$;

-- Recalcula se um dia local está completo. DEVE ser chamada com o lock do pet.
create or replace function public.refresh_pet_day(p_pet uuid, p_date date)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_expected int;
  v_done     int;
begin
  select coalesce(sum(cardinality(daily_times)), 0) into v_expected
  from care_tasks where pet_id = p_pet and active and kind = 'daily';

  if v_expected = 0 then return; end if;

  select count(*) into v_done
  from care_logs l join care_tasks t on t.id = l.task_id
  where l.pet_id = p_pet and l.slot_date = p_date
    and t.active and t.kind = 'daily'
    and l.slot_index < cardinality(t.daily_times);

  if v_done >= v_expected then
    -- Congelamento automático: buraco de exatamente 1 dia consome 1 freeze
    if not exists (select 1 from pet_days where pet_id = p_pet and local_date = p_date - 1)
       and exists (select 1 from pet_days where pet_id = p_pet and local_date = p_date - 2) then
      update pet_streaks set freezes = freezes - 1 where pet_id = p_pet and freezes > 0;
      if found then
        insert into pet_days values (p_pet, p_date - 1, 'frozen') on conflict do nothing;
      end if;
    end if;

    insert into pet_days (pet_id, local_date, status) values (p_pet, p_date, 'complete')
    on conflict (pet_id, local_date) do update set status = 'complete';

    update pet_streaks
       set longest_days = greatest(longest_days, pet_streak(p_pet)), updated_at = now()
     where pet_id = p_pet;
  else
    delete from pet_days where pet_id = p_pet and local_date = p_date and status = 'complete';
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- RPCs DE DOMÍNIO
-- -----------------------------------------------------------------------------

-- Cria household + owner + pet + tarefas numa única transação (sem contas órfãs).
-- Idempotente: se o usuário já possui pet, devolve o existente.
create or replace function public.complete_onboarding(p jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_h   uuid;
  v_pet uuid;
  v_t   jsonb;
begin
  if v_uid is null then raise exception 'unauthenticated' using errcode = '42501'; end if;

  select pt.id into v_pet
  from pets pt join household_members m on m.household_id = pt.household_id
  where m.user_id = v_uid limit 1;
  if found then return v_pet; end if;

  if jsonb_array_length(coalesce(p->'tasks', '[]'::jsonb)) > 20 then
    raise exception 'too_many_tasks' using errcode = '22023';
  end if;

  perform now() at time zone (p->'pet'->>'timezone');   -- valida fuso IANA

  insert into households default values returning id into v_h;

  insert into household_members (household_id, user_id, role, display_name)
  values (v_h, v_uid, 'owner', coalesce(nullif(trim(p->>'display_name'), ''), 'Tutor'));

  insert into pets (household_id, name, species, timezone, avatar_dna)
  values (v_h, trim(p->'pet'->>'name'), p->'pet'->>'species',
          p->'pet'->>'timezone', p->'pet'->'avatar_dna')
  returning id into v_pet;

  insert into pet_streaks (pet_id) values (v_pet);

  for v_t in select * from jsonb_array_elements(coalesce(p->'tasks', '[]'::jsonb)) loop
    insert into care_tasks (pet_id, type, label, kind, daily_times, interval_days, next_due_date)
    values (
      v_pet, v_t->>'type', v_t->>'label', v_t->>'kind',
      case when jsonb_typeof(v_t->'daily_times') = 'array'
           then array(select jsonb_array_elements_text(v_t->'daily_times')::time) end,
      (v_t->>'interval_days')::int,
      (v_t->>'next_due_date')::date
    );
  end loop;

  return v_pet;
end $$;

-- Registra um cuidado. Retorna status 'created' ou 'already_done' (+ quem fez).
create or replace function public.log_care(
  p_log_id      uuid,
  p_task_id     uuid,
  p_slot_index  smallint default 0,
  p_occurred_at timestamptz default now()
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_task   care_tasks;
  v_pet    pets;
  v_date   date;
  v_log    care_logs;
  v_status text := 'created';
begin
  select * into v_task from care_tasks where id = p_task_id and active;
  if not found then raise exception 'task_not_found' using errcode = 'P0002'; end if;

  -- Lock por pet: serializa registros simultâneos dos co-tutores
  select * into v_pet from pets where id = v_task.pet_id for update;
  if not is_member(v_pet.household_id) then raise exception 'forbidden' using errcode = '42501'; end if;

  if p_occurred_at > now() + interval '5 minutes'
     or p_occurred_at < now() - interval '48 hours' then
    raise exception 'occurred_at_out_of_range' using errcode = '22023';
  end if;

  v_date := (p_occurred_at at time zone v_pet.timezone)::date;

  if v_task.kind = 'daily' then
    if p_slot_index < 0 or p_slot_index >= cardinality(v_task.daily_times) then
      raise exception 'invalid_slot' using errcode = '22023';
    end if;
  else
    p_slot_index := 0;
  end if;

  insert into care_logs (id, task_id, pet_id, slot_date, slot_index, done_by, occurred_at, prev_next_due_date)
  values (p_log_id, p_task_id, v_pet.id, v_date, p_slot_index, auth.uid(), p_occurred_at,
          case when v_task.kind = 'interval' then v_task.next_due_date end)
  on conflict do nothing
  returning * into v_log;

  if v_log.id is null then
    select * into v_log from care_logs where id = p_log_id;
    if found then
      if v_log.task_id <> p_task_id then raise exception 'log_id_conflict' using errcode = '23505'; end if;
      -- retry idempotente da fila offline: mantém 'created'
    else
      select * into v_log from care_logs
      where task_id = p_task_id and slot_date = v_date and slot_index = p_slot_index;
      v_status := 'already_done';
    end if;
  else
    if v_task.kind = 'interval' then
      update care_tasks set next_due_date = v_date + interval_days where id = v_task.id;
    end if;
    perform refresh_pet_day(v_pet.id, v_date);
  end if;

  return jsonb_build_object(
    'status', v_status, 'log_id', v_log.id, 'done_by', v_log.done_by,
    'occurred_at', v_log.occurred_at, 'slot_date', v_log.slot_date,
    'streak', pet_streak(v_pet.id)
  );
end $$;

-- Desfaz um registro próprio em até 10 minutos (toque acidental).
create or replace function public.undo_care(p_log_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_log care_logs;
begin
  select * into v_log from care_logs
  where id = p_log_id and done_by = auth.uid() and created_at > now() - interval '10 minutes';
  if not found or not can_access_pet(v_log.pet_id) then
    raise exception 'undo_not_allowed' using errcode = '42501';
  end if;

  perform 1 from pets where id = v_log.pet_id for update;

  delete from care_logs where id = p_log_id;

  if v_log.prev_next_due_date is not null then
    update care_tasks set next_due_date = v_log.prev_next_due_date where id = v_log.task_id;
  end if;

  perform refresh_pet_day(v_log.pet_id, v_log.slot_date);
end $$;

-- Gera código de convite (6 chars, sem I/O/0/1 para evitar confusão ao digitar).
create or replace function public.create_invite(
  p_household   uuid,
  p_role        text default 'member',
  p_sitter_days int  default null
)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_code  text;
  v_alpha constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- 32 símbolos
begin
  if not is_editor(p_household) then raise exception 'forbidden' using errcode = '42501'; end if;
  loop
    select string_agg(substr(v_alpha, 1 + get_byte(uuid_send(gen_random_uuid()), 0) % 32, 1), '')
      into v_code from generate_series(1, 6);
    begin
      insert into household_invites (code, household_id, created_by, role, sitter_days)
      values (v_code, p_household, auth.uid(), p_role, p_sitter_days);
      return v_code;
    exception when unique_violation then
      -- colisão: tenta outro código
    end;
  end loop;
end $$;

create or replace function public.join_household(p_code text, p_display_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_inv household_invites;
begin
  if auth.uid() is null then raise exception 'unauthenticated' using errcode = '42501'; end if;

  select * into v_inv from household_invites where code = upper(trim(p_code)) for update;
  if not found or v_inv.expires_at < now() or v_inv.uses >= v_inv.max_uses then
    raise exception 'invalid_invite' using errcode = '22023';
  end if;

  insert into household_members (household_id, user_id, role, display_name, expires_at)
  values (v_inv.household_id, auth.uid(), v_inv.role,
          coalesce(nullif(trim(p_display_name), ''), 'Tutor'),
          case when v_inv.role = 'sitter' then now() + make_interval(days => v_inv.sitter_days) end)
  on conflict (household_id, user_id) do nothing;

  if found then
    update household_invites set uses = uses + 1 where code = v_inv.code;
  end if;

  return v_inv.household_id;
end $$;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
alter table public.households        enable row level security;
alter table public.household_members enable row level security;
alter table public.pets              enable row level security;
alter table public.care_tasks        enable row level security;
alter table public.care_logs         enable row level security;
alter table public.pet_days          enable row level security;
alter table public.pet_streaks       enable row level security;
alter table public.household_invites enable row level security;
alter table public.push_tokens       enable row level security;

create policy households_select on public.households
  for select using (is_member(id));
create policy households_update on public.households
  for update using (is_editor(id)) with check (is_editor(id));

create policy members_select on public.household_members
  for select using (is_member(household_id));
create policy members_self_update on public.household_members
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy members_self_leave on public.household_members
  for delete using (user_id = auth.uid());

create policy pets_select on public.pets
  for select using (is_member(household_id));
create policy pets_update on public.pets
  for update using (is_editor(household_id)) with check (is_editor(household_id));

create policy tasks_select on public.care_tasks
  for select using (can_access_pet(pet_id));
create policy tasks_insert on public.care_tasks
  for insert with check (can_edit_pet(pet_id));
create policy tasks_update on public.care_tasks
  for update using (can_edit_pet(pet_id)) with check (can_edit_pet(pet_id));

-- care_logs / pet_days / pet_streaks: somente leitura direta; escrita só via RPC
create policy logs_select on public.care_logs
  for select using (can_access_pet(pet_id));
create policy days_select on public.pet_days
  for select using (can_access_pet(pet_id));
create policy streaks_select on public.pet_streaks
  for select using (can_access_pet(pet_id));

-- household_invites: sem policies (acesso apenas via RPC)

create policy push_tokens_own on public.push_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Restrição por coluna (impede escalar role, trocar household, timezone etc.)
revoke update on public.household_members from anon, authenticated;
grant  update (display_name) on public.household_members to authenticated;

revoke update on public.pets from anon, authenticated;
grant  update (name, avatar_dna) on public.pets to authenticated;

revoke update on public.care_tasks from anon, authenticated;
grant  update (label, daily_times, interval_days, next_due_date, active) on public.care_tasks to authenticated;

-- Funções internas não expostas
revoke execute on function public.refresh_pet_day(uuid, date) from public, anon, authenticated;

-- RPCs: apenas usuários autenticados (inclui login anônimo do Supabase)
revoke execute on function public.complete_onboarding(jsonb)                    from public, anon;
revoke execute on function public.log_care(uuid, uuid, smallint, timestamptz)   from public, anon;
revoke execute on function public.undo_care(uuid)                               from public, anon;
revoke execute on function public.create_invite(uuid, text, int)                from public, anon;
revoke execute on function public.join_household(text, text)                    from public, anon;
revoke execute on function public.pet_streak(uuid)                              from public, anon;
grant  execute on function public.complete_onboarding(jsonb)                    to authenticated;
grant  execute on function public.log_care(uuid, uuid, smallint, timestamptz)   to authenticated;
grant  execute on function public.undo_care(uuid)                               to authenticated;
grant  execute on function public.create_invite(uuid, text, int)                to authenticated;
grant  execute on function public.join_household(text, text)                    to authenticated;
grant  execute on function public.pet_streak(uuid)                              to authenticated;

-- -----------------------------------------------------------------------------
-- REALTIME (co-tutores sincronizados)
-- -----------------------------------------------------------------------------
alter publication supabase_realtime
  add table public.care_logs, public.pet_days, public.pets, public.care_tasks;
