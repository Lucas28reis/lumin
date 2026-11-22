-- Family managers can inspect and revoke invitations for their own household.
create policy invites_manage_read on public.household_invites for select to authenticated
using (public.is_editor(household_id));
grant select(code, household_id, role, expires_at, uses, max_uses)
on public.household_invites to authenticated;

create function public.revoke_family_invite(p_household uuid, p_code text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_editor(p_household) then raise insufficient_privilege; end if;
  delete from household_invites where household_id=p_household and code=p_code;
end $$;

create function public.remove_family_member(p_household uuid,p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from household_members where household_id=p_household
    and user_id=auth.uid() and role='owner') then raise insufficient_privilege; end if;
  delete from household_members where household_id=p_household and user_id=p_user and role <> 'owner';
end $$;
revoke all on function public.revoke_family_invite(uuid,text), public.remove_family_member(uuid,uuid) from public,anon;
grant execute on function public.revoke_family_invite(uuid,text), public.remove_family_member(uuid,uuid) to authenticated;
