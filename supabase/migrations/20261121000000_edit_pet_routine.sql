create or replace function public.edit_pet_routine(p_pet uuid, p_meals time[], p_walks time[])
returns void language plpgsql security definer set search_path = public as $$
declare
  today date;
  kind_name text;
  desired time[];
  old_task care_tasks;
  new_id uuid;
begin
  if not can_access_pet(p_pet) then raise insufficient_privilege; end if;
  select (now() at time zone timezone)::date into strict today from pets where id = p_pet for update;
  if p_meals is null or p_walks is null or cardinality(p_meals) not between 1 and 6
     or cardinality(p_walks) > 6 then raise exception 'invalid_schedule'; end if;
  foreach kind_name in array array['feed','walk'] loop
    desired := case when kind_name = 'feed' then p_meals else p_walks end;
    if (select count(distinct t) from unnest(desired) as t) <> cardinality(desired)
      then raise exception 'duplicate_or_null_time'; end if;
    select * into old_task from care_tasks where pet_id = p_pet and type = kind_name and active;
    if coalesce(old_task.daily_times, '{}'::time[]) = desired then continue; end if;
    update care_tasks set active = false where id = old_task.id;
    if cardinality(desired) > 0 then
      insert into care_tasks(pet_id,type,label,kind,daily_times)
        values(p_pet,kind_name,case when kind_name='feed' then 'Alimentar' else 'Passeio' end,'daily',desired)
        returning id into new_id;
      update care_logs set task_id = new_id,
        slot_index = array_position(desired, old_task.daily_times[slot_index+1])-1
        where task_id = old_task.id and slot_date = today
        and old_task.daily_times[slot_index+1] = any(desired);
    end if;
  end loop;
  perform refresh_pet_day(p_pet,today);
end $$;
revoke execute on function public.edit_pet_routine(uuid,time[],time[]) from public, anon;
grant execute on function public.edit_pet_routine(uuid,time[],time[]) to authenticated;

create or replace function public.undo_care(p_log_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_log care_logs;
  today date;
begin
  select * into v_log from care_logs where id = p_log_id and done_by = auth.uid();
  if not found or not can_access_pet(v_log.pet_id) then raise insufficient_privilege; end if;
  select (now() at time zone timezone)::date into today from pets where id = v_log.pet_id for update;
  delete from care_logs where id = p_log_id and slot_date = today and done_by = auth.uid()
    returning * into v_log;
  if not found then raise exception 'undo_not_allowed'; end if;
  if v_log.prev_next_due_date is not null then
    update care_tasks set next_due_date = v_log.prev_next_due_date where id = v_log.task_id;
  end if;
  perform refresh_pet_day(v_log.pet_id,today);
end $$;
