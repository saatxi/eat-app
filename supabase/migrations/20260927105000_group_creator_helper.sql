-- Second bootstrap fix: the creator-membership policy's subquery reads
-- public.groups, but groups' own SELECT policy (is_group_member) hides the
-- group from its not-yet-a-member creator — so the subquery saw no rows and
-- the insert was still rejected. is_group_creator() is SECURITY DEFINER, so
-- its read of groups bypasses RLS and answers the one question the policy
-- needs: "did this user create this group?"

create or replace function public.is_group_creator(target_group_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.groups
    where id = target_group_id and created_by = auth.uid()
  );
$$;

revoke all on function public.is_group_creator(uuid) from public, anon;
grant execute on function public.is_group_creator(uuid) to authenticated;

drop policy "group_members_insert_owner" on public.group_members;

create policy "group_members_insert_owner" on public.group_members
  for insert to authenticated
  with check (
    -- Bootstrap: the group's creator joins their own group as owner.
    (
      role = 'owner'
      and user_id = auth.uid()
      and public.is_group_creator(group_members.group_id)
    )
    -- Normal case: an existing owner adds anyone.
    or public.is_group_owner(group_members.group_id)
  );
