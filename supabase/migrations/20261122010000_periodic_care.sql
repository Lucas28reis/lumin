alter table public.care_tasks add column scheduled_time time;
alter table public.care_tasks drop constraint care_tasks_type_check;
alter table public.care_tasks add constraint care_tasks_type_check
  check(type in ('feed','walk','medication','flea_tick','deworm','custom','bath'));

create function public.edit_pet_care_schedule(p_pet uuid,p_meals time[],p_walks time[],p_changes jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare e record; task_id uuid; today date;
begin
  perform edit_pet_routine(p_pet,p_meals,p_walks);
  select (now() at time zone timezone)::date into strict today from pets where id=p_pet;
  for e in select * from jsonb_each(p_changes) loop
    if e.key not in ('deworm','medication','bath') then raise exception 'invalid_type'; end if;
    select id into task_id from care_tasks where pet_id=p_pet and type=e.key and active;
    if e.value='null'::jsonb then
      update care_tasks set active=false where id=task_id;
    else
      if (e.value->>'days')::int not between 1 and 365 or
        (e.value->>'time')::time is null or (e.value->>'date')::date is null or
        (e.value->>'days') is null then raise exception 'invalid_schedule'; end if;
      if task_id is null then
        insert into care_tasks(pet_id,type,label,kind,interval_days,next_due_date,scheduled_time)
        values(p_pet,e.key,case e.key when 'bath' then 'Banho' when 'deworm' then 'Vermífugo' else 'Remédio' end,
        'interval',(e.value->>'days')::int,(e.value->>'date')::date,(e.value->>'time')::time);
      else
        update care_tasks set interval_days=(e.value->>'days')::int,
          next_due_date=(e.value->>'date')::date,scheduled_time=(e.value->>'time')::time where id=task_id;
      end if;
    end if;
  end loop;
  perform refresh_pet_day(p_pet,today);
end $$;
revoke all on function public.edit_pet_care_schedule(uuid,time[],time[],jsonb) from public,anon;
grant execute on function public.edit_pet_care_schedule(uuid,time[],time[],jsonb) to authenticated;
