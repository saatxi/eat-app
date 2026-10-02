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
-- above. The old per-group policies are replaced further down.
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

drop policy if exists "restaurants_select_member" on public.restaurants;
drop policy if exists "restaurants_insert_member" on public.restaurants;
drop policy if exists "restaurants_update_member" on public.restaurants;
drop policy if exists "restaurants_delete_member" on public.restaurants;

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
