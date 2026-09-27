-- Keep every non-empty group with at least one owner.
--
-- The group_members_delete_owner_or_self policy lets any member remove their
-- own row, which includes an owner leaving. If the last owner did that while
-- other members remained, the group would be unmanageable forever: only an
-- owner can add members (group_members_insert_owner) or delete the group
-- (groups_delete_owner), and there is no ownership-transfer path.
--
-- This trigger refuses that single delete. The owner's way out of a group that
-- still has members is to dissolve it — deleting the group itself, which
-- cascades — rather than to simply leave. A solo owner (the only member) may
-- still leave freely, and expelling members is unaffected.
--
-- The subqueries run with the function owner's rights (SECURITY DEFINER), so
-- they read group_members directly rather than through the caller's RLS.

create or replace function private.ensure_group_has_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Dissolution must not trip this guard: when the group row is being deleted,
  -- Postgres cascades to group_members, and by then the groups row is already
  -- gone (the cascade runs after it). Guarding only while the group still
  -- exists lets the cascade finish and blocks exactly the standalone leave.
  if old.role = 'owner'
    and exists (
      select 1 from public.groups where id = old.group_id
    )
    -- No other owner remains...
    and not exists (
      select 1 from public.group_members
      where group_id = old.group_id
        and role = 'owner'
        and user_id <> old.user_id
    )
    -- ...and the group still has other members.
    and exists (
      select 1 from public.group_members
      where group_id = old.group_id
        and user_id <> old.user_id
    )
  then
    raise exception 'last_owner_cannot_leave';
  end if;
  return old;
end;
$$;

-- Trigger functions are invoked by the system, not by clients, so the EXECUTE
-- grant is revoked from every client role and the private schema stays closed.
revoke all on function private.ensure_group_has_owner()
  from public, anon, authenticated;

create trigger group_members_keep_owner
  before delete on public.group_members
  for each row execute function private.ensure_group_has_owner();
