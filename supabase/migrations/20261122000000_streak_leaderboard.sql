create table public.streak_participants (
  pet_id uuid primary key references public.pets(id) on delete cascade
);
alter table public.streak_participants enable row level security;
create policy family_participation on public.streak_participants for all to authenticated
  using (public.can_access_pet(pet_id)) with check (public.can_access_pet(pet_id));
revoke all on public.streak_participants from public, anon, authenticated;
grant select, insert, delete on public.streak_participants to authenticated;

create function public.streak_leaderboard(p_pet uuid)
returns table("position" bigint, pet_name text, days bigint, mine boolean)
language sql stable security definer set search_path = public as $$
  with participants as (
    select p.id,p.name,(now() at time zone p.timezone)::date as today
    from public.streak_participants sp join public.pets p on p.id=sp.pet_id
    where public.can_access_pet(p_pet)
  ), islands as (
    select d.pet_id,d.local_date,d.status,
      d.local_date - (row_number() over(partition by d.pet_id order by d.local_date))::int as grp
    from public.pet_days d join participants p on p.id=d.pet_id where d.local_date<=p.today
  ), streaks as (
    select pet_id,max(local_date) as last_day,count(*) filter(where status='complete') as days
    from islands group by pet_id,grp
  ), latest as (
    select distinct on(pet_id) * from streaks order by pet_id,last_day desc
  ), scores as (
    select p.id,p.name,case when l.last_day>=p.today-1 then l.days else 0 end as score
    from participants p left join latest l on l.pet_id=p.id
  ), ranked as (
    select *,rank() over(order by score desc) as place,
      row_number() over(order by score desc,name,id) as ordinal from scores
  )
  select place,name,score,id=p_pet from ranked where ordinal<=50 or id=p_pet order by ordinal
$$;
revoke all on function public.streak_leaderboard(uuid) from public,anon;
grant execute on function public.streak_leaderboard(uuid) to authenticated;

