-- Allow a group's creator to insert their own owner membership row.
--
-- group_members_insert_owner required the caller to already be an owner,
-- which is a chicken-and-egg for the group's very first member: the creator
-- is not yet in group_members, so they could create the group but never
-- join it. The fix lets a user insert their own row as 'owner' when the
-- group's created_by is their own id — the one bootstrap case. Everything
-- else (adding other members, later role changes) still requires ownership.

drop policy "group_members_insert_owner" on public.group_members;

create policy "group_members_insert_owner" on public.group_members
  for insert to authenticated
  with check (
    -- Bootstrap: the group's creator joins their own group as owner.
    (
      role = 'owner'
      and user_id = auth.uid()
      and exists (
        select 1 from public.groups g
        where g.id = group_members.group_id and g.created_by = auth.uid()
      )
    )
    -- Normal case: an existing owner adds anyone.
    or public.is_group_owner(group_members.group_id)
  );
