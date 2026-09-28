-- Cap the number of groups a user may own, while leaving membership unlimited.
--
-- A user can belong to any number of groups as a plain member, but may own
-- (create) only a small number — the app's `createGroup` joins the creator as
-- owner of the group they just inserted, and a runaway number of self-owned
-- groups is the spam vector. This is an ownership cap, not a membership cap:
-- an owner who joined someone else's groups as a member is unaffected, and
-- may attend as many as they like.
--
-- The limit lives in private.app_settings so raising it later (e.g. to 5
-- after testing) is a single UPDATE, no migration and no app release. The
-- authenticated RPC public.owner_group_limit() exposes that number to the
-- app for pre-validation; the trigger below is the authoritative check and
-- must never be relaxed on the client's say-so.
--
-- Implementation notes, mirroring the other invariants:
--   * The trigger counts the user's existing owner memberships directly
--     (SECURITY DEFINER, so RLS cannot hide rows from its own count) and
--     rejects a new owner row that would push the user past the cap.
--   * Only the bootstrap (a creator joining their own group as owner) and an
--     existing owner adding another owner can ever insert an owner row, so
--     the check runs once per insert and capping creation is exactly the same
--     as capping "become an owner anywhere".
--   * The group row itself is inserted before the owner membership in the
--     app's createGroup flow; when this trigger rejects the membership, the
--     app deletes the fresh group again (best effort) so no orphan lingers.

create table private.app_settings (
  key text primary key,
  value text not null
);

-- With RLS enabled and no policies, no client role can read or write it.
alter table private.app_settings enable row level security;

insert into private.app_settings (key, value)
values ('owner_group_limit', '2');

-- The number the app may lean on for pre-validation.
create or replace function public.owner_group_limit()
returns integer
language sql
security definer
set search_path = ''
stable
as $$
  select coalesce(
    (select value::integer from private.app_settings where key = 'owner_group_limit'),
    2
  );
$$;

revoke all on function public.owner_group_limit() from public, anon;
grant execute on function public.owner_group_limit() to authenticated;

-- The authoritative guard: reject an owner membership that would put the user
-- over the cap.
create or replace function private.prevent_owner_cap_exceeded()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  cap constant integer := public.owner_group_limit();
  owned integer;
begin
  if new.role = 'owner' then
    select count(*) into owned
    from public.group_members
    where user_id = new.user_id
      and role = 'owner';

    if owned >= cap then
      raise exception 'owner_group_limit_reached'
        using detail = format('%s of %s owned', owned, cap);
    end if;
  end if;
  return new;
end;
$$;

-- Trigger functions are invoked by the system, not by clients, so the EXECUTE
-- grant is revoked from every client role and the private schema stays closed.
revoke all on function private.prevent_owner_cap_exceeded()
  from public, anon, authenticated;

create trigger group_members_owner_cap
  before insert on public.group_members
  for each row execute function private.prevent_owner_cap_exceeded();

-- Atomic group creation: the groups row and the creator's owner membership in
-- one transaction, so a refused membership (the cap trigger above) rolls the
-- group row back instead of leaving an orphan nobody can delete — the client
-- is not an owner yet, so RLS's groups_delete_owner would block the cleanup.
--
-- SECURITY DEFINER: the function guards authorship itself (both rows get
-- auth.uid()), and the cap trigger fires inside regardless of RLS bypass, so
-- the invariant holds. The client calls this instead of the old two-insert
-- flow.
create or replace function public.create_owned_group(p_id uuid, p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  insert into public.groups (id, name, created_by)
  values (p_id, p_name, me);

  insert into public.group_members (group_id, user_id, role)
  values (p_id, me, 'owner');

  return p_id;
end;
$$;

revoke all on function public.create_owned_group(uuid, text) from public, anon;
grant execute on function public.create_owned_group(uuid, text) to authenticated;