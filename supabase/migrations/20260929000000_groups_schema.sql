-- EatApp shared groups — consolidated initial schema.
--
-- One database, logical partition by group_id, RLS on everything. Private data
-- (group_id NULL in the local drift database) never leaves the device, so every
-- shared table declares group_id NOT NULL: the remote refuses to store anything
-- it cannot attribute to a group.
--
-- Identity lives in Supabase's auth.users (signInAnonymously creates a row);
-- profiles only adds the display name. No users table of our own.
--
-- This single file replaces the twelve incremental migrations that grew this
-- schema (initial tables, the RLS-recursion fix, the creator-membership
-- bootstrap fixes, and the owner-cap refinements). The app is not yet in
-- production and no data has to be preserved, so the final state is expressed
-- once, in order, rather than as a chain of drops and re-creates.
--
-- Layout: private schema, then tables in FK order, then helper functions, then
-- policies, then triggers + rate limiting, then grants. The five invariants the
-- app relies on are each documented next to what enforces them.

-- ── private schema (client-invisible internals) ──────────────────────────
create schema if not exists private;

-- ── tables ───────────────────────────────────────────────────────────────

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now()
);

comment on table public.profiles is
  'Display name for each auth user; the identity itself lives in auth.users.';

create table public.groups (
  id uuid primary key,
  name text not null check (char_length(name) between 1 and 80),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create index index_group_members_user_id
  on public.group_members (user_id);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  -- SHA-256 of the invitation token; the raw token never touches the DB.
  token_hash text not null unique,
  expires_at timestamptz not null,
  max_uses integer not null default 10 check (max_uses > 0),
  uses_count integer not null default 0 check (uses_count >= 0),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index index_invites_group_id on public.invites (group_id);

-- Columns mirror the local drift schema (lib/data/db/tables.dart) plus the
-- sync metadata: created_by, updated_at, deleted_at (soft delete — the pull
-- returns tombstones too so deletions propagate). searchText is derived and
-- rebuilt client-side; it is deliberately not stored remotely.

create table public.restaurants (
  id uuid primary key,
  group_id uuid not null references public.groups (id) on delete cascade,
  name text not null,
  "cuisineType" text not null,
  address text,
  "priceRange" integer not null check ("priceRange" between 0 and 6),
  website text,
  instagram text,
  city text,
  region text,
  country text,
  created_by uuid not null references auth.users (id),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index index_restaurants_group_id on public.restaurants (group_id);
create index index_restaurants_group_updated
  on public.restaurants (group_id, updated_at);

create table public.visits (
  id uuid primary key,
  -- Denormalised from the restaurant's group: lets every RLS policy be one
  -- indexed comparison instead of a per-row join.
  group_id uuid not null references public.groups (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id)
    on delete cascade,
  "visitDate" bigint not null,
  rating integer not null check (rating between 0 and 5),
  notes text,
  "priceRange" integer not null check ("priceRange" between 0 and 6),
  created_by uuid not null references auth.users (id),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index index_visits_group_id on public.visits (group_id);
create index index_visits_restaurant_id on public.visits (restaurant_id);
create index index_visits_group_updated on public.visits (group_id, updated_at);

create table public.photos (
  id uuid primary key,
  group_id uuid not null references public.groups (id) on delete cascade,
  restaurant_id uuid references public.restaurants (id) on delete cascade,
  visit_id uuid references public.visits (id) on delete cascade,
  position integer not null default 0,
  -- Path inside the private `photos` storage bucket: {group_id}/{photo_id}.
  storage_path text not null,
  created_by uuid not null references auth.users (id),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index index_photos_group_id on public.photos (group_id);
create index index_photos_restaurant_id on public.photos (restaurant_id);
create index index_photos_visit_id on public.photos (visit_id);
create index index_photos_group_updated on public.photos (group_id, updated_at);

-- ── private tables (rate limiting + settings; no client access) ──────────

create table private.join_attempts (
  user_id uuid not null references auth.users (id) on delete cascade,
  attempted_at timestamptz not null default now()
);

create index index_join_attempts_user_time
  on private.join_attempts (user_id, attempted_at);

create table private.invite_attempts (
  user_id uuid not null references auth.users (id) on delete cascade,
  attempted_at timestamptz not null default now()
);

create index index_invite_attempts_user_time
  on private.invite_attempts (user_id, attempted_at);

create table private.app_settings (
  key text primary key,
  value text not null
);

-- Seed: the owner-group cap the app and the cap trigger both read. The app is
-- not yet in production, so this is seeded at its shipped value (10) directly
-- rather than raised from an earlier default by a follow-up migration.
insert into private.app_settings (key, value)
values ('owner_group_limit', '10');

-- ── RLS: enable on every table ───────────────────────────────────────────

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.invites enable row level security;
alter table public.restaurants enable row level security;
alter table public.visits enable row level security;
alter table public.photos enable row level security;

-- No policies on these: with RLS enabled and no policy, no client role can touch
-- them. Only the SECURITY DEFINER functions below reach them.
alter table private.join_attempts enable row level security;
alter table private.invite_attempts enable row level security;
alter table private.app_settings enable row level security;

-- ── helper functions (SECURITY DEFINER, bypass RLS for policy subqueries) ─
--
-- group_members' policies query group_members, which Postgres rejects as
-- "infinite recursion detected in policy". A SECURITY DEFINER helper runs as its
-- owner (postgres, which bypasses RLS), so the policy's subquery no longer
-- re-enters the table's own policies — and every policy reads the same way.

create or replace function public.is_group_member(target_group_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.group_members
    where group_id = target_group_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_group_owner(target_group_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.group_members
    where group_id = target_group_id
      and user_id = auth.uid()
      and role = 'owner'
  );
$$;

-- The creator-membership bootstrap policy reads public.groups, whose own SELECT
-- policy hides a group from its not-yet-a-member creator. This helper answers
-- "did this user create this group?" with RLS bypassed.
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

-- The number the app may lean on for pre-validation. The authoritative check is
-- the cap trigger below.
create or replace function public.owner_group_limit()
returns integer
language sql
security definer
set search_path = ''
stable
as $$
  select coalesce(
    (select value::integer from private.app_settings where key = 'owner_group_limit'),
    10
  );
$$;

-- ── profiles policies ────────────────────────────────────────────────────

create policy "profiles_select_authenticated" on public.profiles
  for select to authenticated using (true);

create policy "profiles_upsert_own" on public.profiles
  for insert to authenticated with check (id = auth.uid());

create policy "profiles_update_own" on public.profiles
  for update to authenticated using (id = auth.uid())
  with check (id = auth.uid());

-- ── groups policies ──────────────────────────────────────────────────────

create policy "groups_select_member" on public.groups
  for select to authenticated
  using (public.is_group_member(groups.id));

create policy "groups_insert_creator" on public.groups
  for insert to authenticated with check (created_by = auth.uid());

create policy "groups_update_owner" on public.groups
  for update to authenticated
  using (public.is_group_owner(groups.id))
  with check (public.is_group_owner(groups.id));

create policy "groups_delete_owner" on public.groups
  for delete to authenticated
  using (public.is_group_owner(groups.id));

-- ── group_members policies ───────────────────────────────────────────────
-- Members see the roster; a group's creator joins their own group as owner (the
-- one bootstrap case); an existing owner adds anyone; a member may remove their
-- own row (leave); an owner may remove anyone (expel).

create policy "group_members_select_member" on public.group_members
  for select to authenticated
  using (public.is_group_member(group_members.group_id));

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

create policy "group_members_delete_owner_or_self" on public.group_members
  for delete to authenticated
  using (
    user_id = auth.uid() or public.is_group_owner(group_members.group_id)
  );

-- ── invites policies ─────────────────────────────────────────────────────
-- Invites are managed exclusively by the create-invite Edge Function (service
-- role); members may only read the non-secret metadata of their own group's
-- invites so the UI can list active ones. No write policy: clients never create
-- or modify invites directly.

create policy "invites_select_member" on public.invites
  for select to authenticated
  using (public.is_group_member(invites.group_id));

-- ── shared data policies ─────────────────────────────────────────────────
-- One identical quartet per shared table; written out explicitly (no DO
-- block) so each policy is individually visible and testable. Inserts
-- additionally require created_by = auth.uid() so a member cannot forge
-- another member's authorship.

create policy "restaurants_select_member" on public.restaurants
  for select to authenticated
  using (public.is_group_member(restaurants.group_id));

create policy "restaurants_insert_member" on public.restaurants
  for insert to authenticated
  with check (
    created_by = auth.uid() and public.is_group_member(restaurants.group_id)
  );

create policy "restaurants_update_member" on public.restaurants
  for update to authenticated
  using (public.is_group_member(restaurants.group_id))
  with check (public.is_group_member(restaurants.group_id));

create policy "restaurants_delete_member" on public.restaurants
  for delete to authenticated
  using (public.is_group_member(restaurants.group_id));

create policy "visits_select_member" on public.visits
  for select to authenticated
  using (public.is_group_member(visits.group_id));

create policy "visits_insert_member" on public.visits
  for insert to authenticated
  with check (
    created_by = auth.uid() and public.is_group_member(visits.group_id)
  );

create policy "visits_update_member" on public.visits
  for update to authenticated
  using (public.is_group_member(visits.group_id))
  with check (public.is_group_member(visits.group_id));

create policy "visits_delete_member" on public.visits
  for delete to authenticated
  using (public.is_group_member(visits.group_id));

create policy "photos_select_member" on public.photos
  for select to authenticated
  using (public.is_group_member(photos.group_id));

create policy "photos_insert_member" on public.photos
  for insert to authenticated
  with check (
    created_by = auth.uid() and public.is_group_member(photos.group_id)
  );

create policy "photos_update_member" on public.photos
  for update to authenticated
  using (public.is_group_member(photos.group_id))
  with check (public.is_group_member(photos.group_id));

create policy "photos_delete_member" on public.photos
  for delete to authenticated
  using (public.is_group_member(photos.group_id));

-- ── member roster view ───────────────────────────────────────────────────
--
-- One round-trip for the members screen: each membership joined with its
-- member's display name. `security_invoker = true` makes the view obey the
-- *querying* user's RLS on the underlying tables (group_members' member policy
-- and profiles' world-readable policy), so it exposes nothing a direct read
-- would not — a plain view would run as its owner and bypass RLS entirely.

create view public.group_member_profiles
with (security_invoker = true)
as
select
  gm.group_id,
  gm.user_id,
  gm.role,
  coalesce(p.display_name, '') as display_name
from public.group_members gm
left join public.profiles p on p.id = gm.user_id;

-- ── updated_at trigger ───────────────────────────────────────────────────
--
-- The server owns updated_at (it is the final LWW arbiter for pulls), so a
-- client-supplied value is overwritten on every write.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger restaurants_set_updated_at
  before update on public.restaurants
  for each row execute function public.set_updated_at();

create trigger visits_set_updated_at
  before update on public.visits
  for each row execute function public.set_updated_at();

create trigger photos_set_updated_at
  before update on public.photos
  for each row execute function public.set_updated_at();

-- ── invariant: keep every non-empty group with at least one owner ────────
--
-- The delete policy lets any member remove their own row, which includes an
-- owner leaving. If the last owner did that while others remained, the group
-- would be unmanageable forever. This trigger refuses that single delete; the
-- owner's way out is to dissolve the group (deleting the groups row, which
-- cascades). A solo owner may still leave freely, and expelling is unaffected.

create or replace function private.ensure_group_has_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Dissolution must not trip this guard: when the group row is being deleted,
  -- Postgres cascades to group_members and the groups row is already gone.
  if old.role = 'owner'
    and exists (select 1 from public.groups where id = old.group_id)
    and not exists (
      select 1 from public.group_members
      where group_id = old.group_id
        and role = 'owner'
        and user_id <> old.user_id
    )
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

create trigger group_members_keep_owner
  before delete on public.group_members
  for each row execute function private.ensure_group_has_owner();

-- ── invariant: dissolve a group when the last member leaves ──────────────
--
-- A leave that empties a group would otherwise strand an empty group nobody can
-- reach. An AFTER DELETE checks whether any membership remains; when none does,
-- it deletes the groups row and the foreign keys cascade everything away.

create or replace function private.dissolve_group_when_empty()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.group_members
    where group_id = old.group_id
  ) then
    -- Harmless mid-cascade when the whole group is already being dissolved —
    -- the row is gone by then, so this deletes nothing.
    delete from public.groups where id = old.group_id;
  end if;
  return null;
end;
$$;

create trigger group_members_dissolve_when_empty
  after delete on public.group_members
  for each row execute function private.dissolve_group_when_empty();

-- ── invariant: cap the number of groups a user may own ───────────────────
--
-- A user may belong to any number of groups as a plain member but may own
-- (create) only a small number; a runaway number of self-owned groups is the
-- spam vector. This is an ownership cap, not a membership cap. The limit lives
-- in private.app_settings so raising it later is a single UPDATE; the trigger is
-- authoritative and must never be relaxed on the client's say-so.

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
      -- A dedicated SQLSTATE so the client can recognise this case without
      -- parsing the human-readable message (which may be reworded). Mirrored by
      -- ownerGroupLimitReachedCode in lib/data/groups/group_models.dart.
      raise exception 'owner_group_limit_reached'
        using errcode = 'P0A01',
              detail = format('%s of %s owned', owned, cap);
    end if;
  end if;
  return new;
end;
$$;

create trigger group_members_owner_cap
  before insert on public.group_members
  for each row execute function private.prevent_owner_cap_exceeded();

-- Atomic group creation: the groups row and the creator's owner membership in
-- one transaction, so a refused membership (the cap trigger) rolls the group
-- row back instead of leaving an orphan nobody can delete. SECURITY DEFINER: the
-- function guards authorship itself (both rows get auth.uid()), and the cap
-- trigger fires inside regardless of RLS bypass.
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

-- ── rate limiting for the two Edge Functions ─────────────────────────────
--
-- The functions call these RPCs before doing anything else. SECURITY DEFINER
-- because the attempts tables must not be readable or writable by clients (RLS
-- on them denies everyone), while the function only exposes pass/fail. Attempts
-- are recorded on every call, so failed guesses count toward the limit too.

create or replace function public.record_join_attempt()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Sliding window: 10 attempts per user per 10 minutes.
  if (
    select count(*) from private.join_attempts
    where user_id = auth.uid()
      and attempted_at > now() - interval '10 minutes'
  ) >= 10 then
    raise exception 'join_attempts_rate_limited';
  end if;

  insert into private.join_attempts (user_id) values (auth.uid());

  -- Opportunistic cleanup of this user's stale rows.
  delete from private.join_attempts
  where user_id = auth.uid()
    and attempted_at < now() - interval '1 day';
end;
$$;

create or replace function public.record_invite_attempt()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Sliding window: 20 invitations minted per user per hour.
  if (
    select count(*) from private.invite_attempts
    where user_id = auth.uid()
      and attempted_at > now() - interval '1 hour'
  ) >= 20 then
    raise exception 'invite_attempts_rate_limited';
  end if;

  insert into private.invite_attempts (user_id) values (auth.uid());

  -- Opportunistic cleanup of this user's stale rows.
  delete from private.invite_attempts
  where user_id = auth.uid()
    and attempted_at < now() - interval '1 day';
end;
$$;

-- ── storage: private photos bucket ───────────────────────────────────────

insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

-- Path layout is {group_id}/{photo_id}; the first path segment must be a
-- group the caller belongs to.
create policy "photos_storage_member_all" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'photos'
    and exists (
      select 1 from public.group_members gm
      where gm.group_id::text = (storage.foldername(name))[1]
        and gm.user_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'photos'
    and exists (
      select 1 from public.group_members gm
      where gm.group_id::text = (storage.foldername(name))[1]
        and gm.user_id = auth.uid()
    )
  );

-- ── grants ───────────────────────────────────────────────────────────────
--
-- Tables created by migrations run as postgres, which does not carry the
-- dashboard's default privileges, so anon/authenticated/service_role would end
-- up with no grants at all. RLS is what actually restricts anon/authenticated;
-- service_role bypasses RLS but still needs table privileges.

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on
  public.profiles,
  public.groups,
  public.group_members,
  public.invites,
  public.restaurants,
  public.visits,
  public.photos
to anon, authenticated, service_role;

-- The roster view is read-only; member-scoping comes from the underlying RLS.
grant select on public.group_member_profiles to authenticated, service_role;

-- The helper and mutating RPCs are callable by authenticated users only.
revoke all on function public.is_group_member(uuid) from public, anon;
revoke all on function public.is_group_owner(uuid) from public, anon;
revoke all on function public.is_group_creator(uuid) from public, anon;
revoke all on function public.owner_group_limit() from public, anon;
revoke all on function public.record_join_attempt() from public, anon;
revoke all on function public.record_invite_attempt() from public, anon;
revoke all on function public.create_owned_group(uuid, text) from public, anon;

grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.is_group_owner(uuid) to authenticated;
grant execute on function public.is_group_creator(uuid) to authenticated;
grant execute on function public.owner_group_limit() to authenticated;
grant execute on function public.record_join_attempt() to authenticated;
grant execute on function public.record_invite_attempt() to authenticated;
grant execute on function public.create_owned_group(uuid, text) to authenticated;

-- Trigger functions are invoked by the system, not by clients, so the EXECUTE
-- grant is revoked from every client role and the private schema stays closed.
revoke all on function private.ensure_group_has_owner()
  from public, anon, authenticated;
revoke all on function private.dissolve_group_when_empty()
  from public, anon, authenticated;
revoke all on function private.prevent_owner_cap_exceeded()
  from public, anon, authenticated;
