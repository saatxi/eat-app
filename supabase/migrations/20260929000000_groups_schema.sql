-- EatApp shared-groups baseline schema.
--
-- One migration for a database created from scratch: it folds together, in
-- order, everything the earlier incremental migrations built up, so a fresh
-- project gets the final schema in a single step. The app is not in production,
-- so there is no upgrade path to preserve — an existing project is reset rather
-- than migrated forward.

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

-- One attempts table for both rate-limited Edge Functions; `kind` separates the
-- join flow ('join') from the invite-minting flow ('invite').
create table private.rate_attempts (
  kind text not null check (kind in ('join', 'invite')),
  user_id uuid not null references auth.users (id) on delete cascade,
  attempted_at timestamptz not null default now()
);

create index index_rate_attempts_kind_user_time
  on private.rate_attempts (kind, user_id, attempted_at);

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
alter table private.rate_attempts enable row level security;
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
-- Both Edge Functions call this before doing anything else, passing their own
-- kind. SECURITY DEFINER because the attempts table must not be readable or
-- writable by clients (RLS on it denies everyone), while the function only
-- exposes pass/fail. An attempt is recorded on every call — including a rejected
-- one — so failed guesses count toward the limit too.

create or replace function public.record_rate_attempt(attempt_kind text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  window_interval interval;
  max_attempts integer;
begin
  -- Per-kind sliding window: token guessing is cheap, so joins are throttled
  -- hard (10 per 10 minutes) while invites stay generous for a person handing
  -- them out one at a time (20 per hour).
  select
    case attempt_kind when 'join' then interval '10 minutes'
                      when 'invite' then interval '1 hour' end,
    case attempt_kind when 'join' then 10
                      when 'invite' then 20 end
  into window_interval, max_attempts;

  if window_interval is null then
    raise exception 'unknown_rate_attempt_kind: %', attempt_kind
      using errcode = '22023';
  end if;

  if (
    select count(*) from private.rate_attempts
    where kind = attempt_kind
      and user_id = auth.uid()
      and attempted_at > now() - window_interval
  ) >= max_attempts then
    raise exception 'rate_limited';
  end if;

  insert into private.rate_attempts (kind, user_id)
  values (attempt_kind, auth.uid());

  -- Opportunistic cleanup of this user's stale rows for this kind.
  delete from private.rate_attempts
  where kind = attempt_kind
    and user_id = auth.uid()
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
revoke all on function public.record_rate_attempt(text) from public, anon;
revoke all on function public.create_owned_group(uuid, text) from public, anon;

grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.is_group_owner(uuid) to authenticated;
grant execute on function public.is_group_creator(uuid) to authenticated;
grant execute on function public.owner_group_limit() to authenticated;
grant execute on function public.record_rate_attempt(text) to authenticated;
grant execute on function public.create_owned_group(uuid, text) to authenticated;

-- Trigger functions are invoked by the system, not by clients, so the EXECUTE
-- grant is revoked from every client role and the private schema stays closed.
revoke all on function private.ensure_group_has_owner()
  from public, anon, authenticated;
revoke all on function private.dissolve_group_when_empty()
  from public, anon, authenticated;
revoke all on function private.prevent_owner_cap_exceeded()
  from public, anon, authenticated;
-- EatApp shared groups — three roles and restaurant↔group membership.
--
-- Two structural changes on top of 20260929000000_groups_schema.sql:
--
--   1. group_members.role gains a middle role. It is now
--      owner | editor | reader. The old 'member' becomes 'editor', since a
--      plain member could already write; a 'reader' is the new read-only role.
--
--   2. A restaurant is no longer scoped to one group by restaurants.group_id.
--      Membership moves to public.restaurant_groups, a many-to-many junction,
--      so one canonical restaurant can be shared into several groups at once.
--      visits and photos stay children of the restaurant and inherit its
--      visibility: a member of *any* group the restaurant is in can see them.
--
-- Plus group_tags (organise groups) and audit_log (change management).
--
-- The app is not yet in production, but this migration is incremental and
-- backfills existing rows so a development project does not have to be reset.

-- ── 1. roles: owner | editor | reader ────────────────────────────────────

alter table public.group_members
  drop constraint if exists group_members_role_check;

update public.group_members set role = 'editor' where role = 'member';

alter table public.group_members
  add constraint group_members_role_check
  check (role in ('owner', 'editor', 'reader'));

-- ── 2. restaurant ↔ group junction ───────────────────────────────────────

create table public.restaurant_groups (
  restaurant_id uuid not null
    references public.restaurants (id) on delete cascade,
  group_id uuid not null
    references public.groups (id) on delete cascade,
  -- Attributed inserter and sync metadata, mirroring the shared tables.
  created_by uuid not null references auth.users (id),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (restaurant_id, group_id)
);

create index index_restaurant_groups_group_id
  on public.restaurant_groups (group_id);
create index index_restaurant_groups_restaurant_id
  on public.restaurant_groups (restaurant_id);
create index index_restaurant_groups_group_updated
  on public.restaurant_groups (group_id, updated_at);

-- Backfill: each existing shared restaurant joins the one group its group_id
-- named. A private restaurant (group_id null) has no membership, as before.
insert into public.restaurant_groups (restaurant_id, group_id, created_by)
select id, group_id, created_by
from public.restaurants
where group_id is not null
on conflict do nothing;

-- restaurants no longer carries its own group; membership is the junction
-- above. The old per-group policies reference group_id and must be dropped
-- before the column, or the DROP COLUMN is refused; the replacement policies
-- are created in section 7. (An index on the column is dropped with it.)
drop policy if exists "restaurants_select_member" on public.restaurants;
drop policy if exists "restaurants_insert_member" on public.restaurants;
drop policy if exists "restaurants_update_member" on public.restaurants;
drop policy if exists "restaurants_delete_member" on public.restaurants;

alter table public.restaurants drop column if exists group_id;

-- visits/photos keep a nullable home_group (the group the row was first shared
-- into, which names the Storage folder for a photo); visibility is derived
-- from the restaurant's memberships, not this column.
alter table public.visits alter column group_id drop not null;
alter table public.photos alter column group_id drop not null;

-- ── 3. group tags (organisation) ─────────────────────────────────────────

create table public.group_tags (
  group_id uuid not null references public.groups (id) on delete cascade,
  tag text not null check (char_length(tag) between 1 and 40),
  primary key (group_id, tag)
);

create index index_group_tags_tag on public.group_tags (tag);

-- ── 4. audit log (change management) ─────────────────────────────────────

create table public.audit_log (
  id bigint generated always as identity primary key,
  -- Nullable because a restaurant row has no single group: its membership
  -- lives in the junction, and a change there logs its own row per group.
  group_id uuid references public.groups (id) on delete cascade,
  actor_id uuid references auth.users (id) on delete set null,
  table_name text not null,
  row_id uuid not null,
  action text not null check (action in ('insert', 'update', 'delete')),
  at timestamptz not null default now()
);

create index index_audit_log_group_id
  on public.audit_log (group_id, at desc);

-- ── 5. RLS on the new tables ─────────────────────────────────────────────

alter table public.restaurant_groups enable row level security;
alter table public.group_tags enable row level security;
alter table public.audit_log enable row level security;

-- ── 6. helper functions ──────────────────────────────────────────────────

-- Owner or editor: may write a group's shared data. Distinct from
-- is_group_owner, which gates group/member management.
create or replace function public.is_group_editor(target_group_id uuid)
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
      and role in ('owner', 'editor')
  );
$$;

-- A restaurant is readable by any member of any group it belongs to (a live
-- membership row), or always by its own author — that last clause is what lets
-- an author read back the restaurant they just inserted before its junction
-- rows land, and clean up a half-created one.
create or replace function public.can_read_restaurant(target_restaurant_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.restaurant_groups rg
    where rg.restaurant_id = target_restaurant_id
      and rg.deleted_at is null
      and public.is_group_member(rg.group_id)
  );
$$;

create or replace function public.can_edit_restaurant(target_restaurant_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.restaurant_groups rg
    where rg.restaurant_id = target_restaurant_id
      and rg.deleted_at is null
      and public.is_group_editor(rg.group_id)
  );
$$;

-- A photo hangs off either a restaurant directly or one of its visits. Both
-- resolve to the restaurant, whose memberships decide visibility.
create or replace function public.can_read_photo(
  p_restaurant_id uuid,
  p_visit_id uuid
)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select public.can_read_restaurant(
    coalesce(
      p_restaurant_id,
      (select restaurant_id from public.visits where id = p_visit_id)
    )
  );
$$;

create or replace function public.can_edit_photo(
  p_restaurant_id uuid,
  p_visit_id uuid
)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select public.can_edit_restaurant(
    coalesce(
      p_restaurant_id,
      (select restaurant_id from public.visits where id = p_visit_id)
    )
  );
$$;

-- ── 7. replace the shared-data policies ──────────────────────────────────
-- The restaurants quartet no longer reads a group_id column; visibility comes
-- from the junction. visits/photos derive visibility from their restaurant.

create policy "restaurants_select_visible" on public.restaurants
  for select to authenticated
  using (created_by = auth.uid() or public.can_read_restaurant(restaurants.id));

create policy "restaurants_insert_author" on public.restaurants
  for insert to authenticated
  with check (created_by = auth.uid());

create policy "restaurants_update_editor" on public.restaurants
  for update to authenticated
  using (created_by = auth.uid() or public.can_edit_restaurant(restaurants.id))
  with check (created_by = auth.uid() or public.can_edit_restaurant(restaurants.id));

create policy "restaurants_delete_editor" on public.restaurants
  for delete to authenticated
  using (created_by = auth.uid() or public.can_edit_restaurant(restaurants.id));

-- visits
drop policy if exists "visits_select_member" on public.visits;
drop policy if exists "visits_insert_member" on public.visits;
drop policy if exists "visits_update_member" on public.visits;
drop policy if exists "visits_delete_member" on public.visits;

create policy "visits_select_visible" on public.visits
  for select to authenticated
  using (public.can_read_restaurant(visits.restaurant_id));

create policy "visits_insert_editor" on public.visits
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and public.can_edit_restaurant(visits.restaurant_id)
  );

create policy "visits_update_editor" on public.visits
  for update to authenticated
  using (public.can_edit_restaurant(visits.restaurant_id))
  with check (public.can_edit_restaurant(visits.restaurant_id));

create policy "visits_delete_editor" on public.visits
  for delete to authenticated
  using (public.can_edit_restaurant(visits.restaurant_id));

-- photos
drop policy if exists "photos_select_member" on public.photos;
drop policy if exists "photos_insert_member" on public.photos;
drop policy if exists "photos_update_member" on public.photos;
drop policy if exists "photos_delete_member" on public.photos;

create policy "photos_select_visible" on public.photos
  for select to authenticated
  using (public.can_read_photo(photos.restaurant_id, photos.visit_id));

create policy "photos_insert_editor" on public.photos
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and public.can_edit_photo(photos.restaurant_id, photos.visit_id)
  );

create policy "photos_update_editor" on public.photos
  for update to authenticated
  using (public.can_edit_photo(photos.restaurant_id, photos.visit_id))
  with check (public.can_edit_photo(photos.restaurant_id, photos.visit_id));

create policy "photos_delete_editor" on public.photos
  for delete to authenticated
  using (public.can_edit_photo(photos.restaurant_id, photos.visit_id));

-- restaurant_groups: a member reads their group's memberships; an editor adds
-- or removes them, attributed to themselves.
create policy "restaurant_groups_select_member" on public.restaurant_groups
  for select to authenticated
  using (public.is_group_member(restaurant_groups.group_id));

create policy "restaurant_groups_insert_editor" on public.restaurant_groups
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and public.is_group_editor(restaurant_groups.group_id)
  );

create policy "restaurant_groups_update_editor" on public.restaurant_groups
  for update to authenticated
  using (public.is_group_editor(restaurant_groups.group_id))
  with check (public.is_group_editor(restaurant_groups.group_id));

create policy "restaurant_groups_delete_editor" on public.restaurant_groups
  for delete to authenticated
  using (public.is_group_editor(restaurant_groups.group_id));

-- group_tags: a member reads; an owner writes (organisation is management).
create policy "group_tags_select_member" on public.group_tags
  for select to authenticated
  using (public.is_group_member(group_tags.group_id));

create policy "group_tags_insert_owner" on public.group_tags
  for insert to authenticated
  with check (public.is_group_owner(group_tags.group_id));

create policy "group_tags_delete_owner" on public.group_tags
  for delete to authenticated
  using (public.is_group_owner(group_tags.group_id));

-- audit_log: members read their group's history; only triggers (security
-- definer) write it, so there is no client insert/update/delete policy.
create policy "audit_log_select_member" on public.audit_log
  for select to authenticated
  using (
    audit_log.group_id is not null
    and public.is_group_member(audit_log.group_id)
  );

-- ── 8. group_members: owners may change roles ────────────────────────────

create policy "group_members_update_owner" on public.group_members
  for update to authenticated
  using (public.is_group_owner(group_members.group_id))
  with check (public.is_group_owner(group_members.group_id));

-- ── 9. invariant: a group keeps at least one owner across role changes ───

create or replace function private.keep_group_owner_on_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'owner'
    and new.role <> 'owner'
    and not exists (
      select 1 from public.group_members
      where group_id = old.group_id
        and role = 'owner'
        and user_id <> old.user_id
    )
  then
    raise exception 'last_owner_cannot_be_demoted';
  end if;
  return new;
end;
$$;

create trigger group_members_keep_owner_on_update
  before update on public.group_members
  for each row execute function private.keep_group_owner_on_role_change();

-- ── 10. audit triggers ───────────────────────────────────────────────────
-- One function, attached to each shared table. group_id is taken from the row
-- where the table has one; restaurant_groups is the source of a restaurant's
-- group context, so membership changes are logged per group.

create or replace function private.log_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rec jsonb := to_jsonb(coalesce(new, old));
  gid uuid := (rec ->> 'group_id')::uuid;
  rid uuid := coalesce((rec ->> 'id')::uuid, (rec ->> 'restaurant_id')::uuid);
begin
  insert into public.audit_log (group_id, actor_id, table_name, row_id, action)
  values (gid, auth.uid(), tg_table_name, rid, lower(tg_op));
  return coalesce(new, old);
end;
$$;

create trigger restaurant_groups_audit
  after insert or update or delete on public.restaurant_groups
  for each row execute function private.log_change();

create trigger visits_audit
  after insert or update or delete on public.visits
  for each row execute function private.log_change();

create trigger photos_audit
  after insert or update or delete on public.photos
  for each row execute function private.log_change();

create trigger group_members_audit
  after insert or update or delete on public.group_members
  for each row execute function private.log_change();

-- ── 11. updated_at on the junction ───────────────────────────────────────

create trigger restaurant_groups_set_updated_at
  before update on public.restaurant_groups
  for each row execute function public.set_updated_at();

-- ── 12. invariant: a restaurant with no group left is deleted ─────────────
--
-- With no group_id column, a restaurant belongs to groups only through the
-- junction. Removing its last membership — a hard delete, or a tombstone that
-- sets deleted_at — must not strand an unreachable row, so it is deleted, and
-- its visits and photos cascade with it. Dissolving a group cascades the
-- junction rows, which reaches this same cleanup.

create or replace function private.prune_orphan_restaurant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := coalesce(new.restaurant_id, old.restaurant_id);
begin
  if not exists (
    select 1 from public.restaurant_groups
    where restaurant_id = rid and deleted_at is null
  ) then
    -- Harmless mid-cascade: the row is already gone then, so this deletes
    -- nothing (and its own cascade does not re-fire into a loop).
    delete from public.restaurants where id = rid;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger restaurant_groups_prune_orphans
  after insert or update or delete on public.restaurant_groups
  for each row execute function private.prune_orphan_restaurant();

-- ── 12. grants ───────────────────────────────────────────────────────────

grant select, insert, update, delete on public.restaurant_groups
  to anon, authenticated, service_role;
grant select, insert, delete on public.group_tags
  to anon, authenticated, service_role;
grant select on public.audit_log to authenticated, service_role;

revoke all on function public.is_group_editor(uuid) from public, anon;
revoke all on function public.can_read_restaurant(uuid) from public, anon;
revoke all on function public.can_edit_restaurant(uuid) from public, anon;

grant execute on function public.is_group_editor(uuid) to authenticated;
grant execute on function public.can_read_restaurant(uuid) to authenticated;
grant execute on function public.can_edit_restaurant(uuid) to authenticated;

-- Trigger functions are system-invoked; keep them out of every client role.
revoke all on function private.keep_group_owner_on_role_change()
  from public, anon, authenticated;
revoke all on function private.log_change()
  from public, anon, authenticated;
-- Fix the audit trigger's row_id for group_members rows.
--
-- private.log_change derived row_id from the 'id' or 'restaurant_id' column,
-- but group_members has neither — its key is (group_id, user_id) — so the
-- insert failed audit_log.row_id's NOT NULL constraint on every membership
-- change. Fall back to user_id as well. Recreating the function is enough;
-- the triggers already point at it.

create or replace function private.log_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rec jsonb := to_jsonb(coalesce(new, old));
  gid uuid := (rec ->> 'group_id')::uuid;
  rid uuid := coalesce(
    (rec ->> 'id')::uuid,
    (rec ->> 'user_id')::uuid,
    (rec ->> 'restaurant_id')::uuid
  );
begin
  insert into public.audit_log (group_id, actor_id, table_name, row_id, action)
  values (gid, auth.uid(), tg_table_name, rid, lower(tg_op));
  return coalesce(new, old);
end;
$$;

-- Trigger functions are system-invoked; keep them out of every client role.
revoke all on function private.log_change() from public, anon, authenticated;
-- Skip the audit insert for a group that is being removed.
--
-- When a group is deleted, the cascade reaches group_members, restaurant_groups
-- and the shared rows after the groups row is already gone, so logging those
-- cascaded deletes hit audit_log.group_id's foreign key. There is nothing
-- meaningful to record against a group that is being dissolved — its existing
-- audit rows cascade away with it — so the trigger returns early in that case.

create or replace function private.log_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rec jsonb := to_jsonb(coalesce(new, old));
  gid uuid := (rec ->> 'group_id')::uuid;
  rid uuid := coalesce(
    (rec ->> 'id')::uuid,
    (rec ->> 'user_id')::uuid,
    (rec ->> 'restaurant_id')::uuid
  );
begin
  if gid is not null
    and not exists (select 1 from public.groups where id = gid)
  then
    return coalesce(new, old);
  end if;

  insert into public.audit_log (group_id, actor_id, table_name, row_id, action)
  values (gid, auth.uid(), tg_table_name, rid, lower(tg_op));
  return coalesce(new, old);
end;
$$;

revoke all on function private.log_change() from public, anon, authenticated;
-- EatApp account identity — rate limiting for the adopt-account Edge Function.
--
-- Sign-in no longer uses email. An account is a code from which credentials are
-- derived server-side (see supabase/functions/adopt-account). That function is
-- unauthenticated by necessity — the caller has no session yet — so a rate
-- limit is what stands between a short code and brute force.
--
-- Two sliding windows, both recorded on every attempt (a rejected guess counts
-- too, the same way record_rate_attempt does):
--   * per code   — throttles hammering one account.
--   * per client — throttles a single source cycling through many codes.
-- Only the SHA-256 of the code is stored, and the table sits in the private
-- schema, unreachable by every client role.

create table private.account_attempts (
  code_hash text not null,
  client_key text not null,
  attempted_at timestamptz not null default now()
);

create index index_account_attempts_code
  on private.account_attempts (code_hash, attempted_at);

create index index_account_attempts_client
  on private.account_attempts (client_key, attempted_at);

-- SECURITY DEFINER because the attempts table must stay private, while the
-- function only exposes pass/fail. No user_id: the caller is not authenticated.
create or replace function public.record_account_attempt(
  p_code_hash text,
  p_client_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  window_interval constant interval := interval '10 minutes';
  per_code_max constant integer := 10;
  per_client_max constant integer := 30;
begin
  if (
    select count(*) from private.account_attempts
    where code_hash = p_code_hash
      and attempted_at > now() - window_interval
  ) >= per_code_max then
    raise exception 'rate_limited';
  end if;

  if (
    select count(*) from private.account_attempts
    where client_key = p_client_key
      and attempted_at > now() - window_interval
  ) >= per_client_max then
    raise exception 'rate_limited';
  end if;

  insert into private.account_attempts (code_hash, client_key)
  values (p_code_hash, p_client_key);

  -- Opportunistic cleanup of stale rows.
  delete from private.account_attempts
  where attempted_at < now() - interval '1 day';
end;
$$;

-- Only the service role (the Edge Function) may call it; clients never do.
revoke all on function public.record_account_attempt(text, text)
  from public, anon, authenticated;
grant execute on function public.record_account_attempt(text, text)
  to service_role;
