-- Dissolve a group when the last member leaves.
--
-- private.ensure_group_has_owner() (the group_members_keep_owner guard) stops
-- the last owner from leaving while anyone else remains, so the only way a
-- leave can empty a group is when the leaver was its last member — a solo
-- owner who expels nobody because there is nobody left to expel, or a lone
-- member after everyone else has gone. Leaving in that situation otherwise
-- strands an empty group nobody can reach: groups_select_member requires a
-- membership to show a row, and with the last membership gone no owner is
-- left to dissolve it (groups_delete_owner needs an owner membership the
-- leaver has just lost).
--
-- So an AFTER DELETE on group_members checks whether any membership remains.
-- When none does, it deletes the group row and the foreign keys cascade every
-- member, invite, restaurant, visit and photo away. The function runs with the
-- function owner's rights (SECURITY DEFINER) because the caller — by
-- definition the one who just left — no longer has a membership that RLS can
-- see by the time the trigger fires; `set search_path = ''` pins every lookup
-- to the public schema, same as the ownership guard.
--
-- This is the complement of private.ensure_group_has_owner(): that trigger
-- refuses the leave that would orphan a non-empty group, this one cleans up
-- after the leave that empties it.

create or replace function private.dissolve_group_when_empty()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Only act when this deletion was the last one: leaving while someone
  -- remains is a plain leave and the group is kept.
  if not exists (
    select 1 from public.group_members
    where group_id = old.group_id
  ) then
    -- Deletes the group row; the foreign keys cascade every remaining shared
    -- row. Harmless mid-cascade when the whole group is already being
    -- dissolved — the row is gone by then, so this deletes nothing.
    delete from public.groups where id = old.group_id;
  end if;
  return null;
end;
$$;

-- Trigger functions are invoked by the system, not by clients, so the EXECUTE
-- grant is revoked from every client role and the private schema stays closed.
revoke all on function private.dissolve_group_when_empty()
  from public, anon, authenticated;

create trigger group_members_dissolve_when_empty
  after delete on public.group_members
  for each row execute function private.dissolve_group_when_empty();