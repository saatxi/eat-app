-- EatApp shared groups — initial schema.
--
-- One database, logical partition by group_id, RLS on everything. Private
-- data (group_id NULL in the local drift database) never leaves the device,
-- so every shared table here declares group_id NOT NULL: the remote refuses
-- to store anything it cannot attribute to a group.
--
-- Identity lives in Supabase's own auth.users (signInAnonymously creates a
-- row there); profiles only adds the display name. No users table of our own.
--
-- Layout: all tables first (policies reference group_members, so every table
-- must exist before any policy is created), then policies, then triggers,
-- then storage.

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

-- ── RLS: enable on every table ───────────────────────────────────────────

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.invites enable row level security;
alter table public.restaurants enable row level security;
alter table public.visits enable row level security;
alter table public.photos enable row level security;

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
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = groups.id and gm.user_id = auth.uid()
    )
  );

create policy "groups_insert_creator" on public.groups
  for insert to authenticated with check (created_by = auth.uid());

create policy "groups_update_owner" on public.groups
  for update to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = groups.id
        and gm.user_id = auth.uid()
        and gm.role = 'owner'
    )
  )
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = groups.id
        and gm.user_id = auth.uid()
        and gm.role = 'owner'
    )
  );

create policy "groups_delete_owner" on public.groups
  for delete to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = groups.id
        and gm.user_id = auth.uid()
        and gm.role = 'owner'
    )
  );

-- ── group_members policies ───────────────────────────────────────────────
-- Members see the roster; only owners add anyone; a member may remove their
-- own row (leave the group); owners may remove anyone (expel).

create policy "group_members_select_member" on public.group_members
  for select to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = group_members.group_id and gm.user_id = auth.uid()
    )
  );

create policy "group_members_insert_owner" on public.group_members
  for insert to authenticated
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = group_members.group_id
        and gm.user_id = auth.uid()
        and gm.role = 'owner'
    )
  );

create policy "group_members_delete_owner_or_self" on public.group_members
  for delete to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.group_members gm
      where gm.group_id = group_members.group_id
        and gm.user_id = auth.uid()
        and gm.role = 'owner'
    )
  );

-- ── invites policies ─────────────────────────────────────────────────────
-- Invites are managed exclusively by the join-group Edge Function (service
-- role); members may only read the non-secret metadata of their own group's
-- invites so the UI can list active ones. No write policy: clients never
-- create or modify invites directly.

create policy "invites_select_member" on public.invites
  for select to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = invites.group_id and gm.user_id = auth.uid()
    )
  );

-- ── shared data policies ─────────────────────────────────────────────────
-- One identical quartet per shared table; written out explicitly (no DO
-- block) so each policy is individually visible and testable. Inserts
-- additionally require created_by = auth.uid() so a member cannot forge
-- another member's authorship.

create policy "restaurants_select_member" on public.restaurants
  for select to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = restaurants.group_id and gm.user_id = auth.uid()
    )
  );

create policy "restaurants_insert_member" on public.restaurants
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = restaurants.group_id and gm.user_id = auth.uid()
    )
  );

create policy "restaurants_update_member" on public.restaurants
  for update to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = restaurants.group_id and gm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = restaurants.group_id and gm.user_id = auth.uid()
    )
  );

create policy "restaurants_delete_member" on public.restaurants
  for delete to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = restaurants.group_id and gm.user_id = auth.uid()
    )
  );

create policy "visits_select_member" on public.visits
  for select to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = visits.group_id and gm.user_id = auth.uid()
    )
  );

create policy "visits_insert_member" on public.visits
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = visits.group_id and gm.user_id = auth.uid()
    )
  );

create policy "visits_update_member" on public.visits
  for update to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = visits.group_id and gm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = visits.group_id and gm.user_id = auth.uid()
    )
  );

create policy "visits_delete_member" on public.visits
  for delete to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = visits.group_id and gm.user_id = auth.uid()
    )
  );

create policy "photos_select_member" on public.photos
  for select to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = photos.group_id and gm.user_id = auth.uid()
    )
  );

create policy "photos_insert_member" on public.photos
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = photos.group_id and gm.user_id = auth.uid()
    )
  );

create policy "photos_update_member" on public.photos
  for update to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = photos.group_id and gm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = photos.group_id and gm.user_id = auth.uid()
    )
  );

create policy "photos_delete_member" on public.photos
  for delete to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = photos.group_id and gm.user_id = auth.uid()
    )
  );

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
