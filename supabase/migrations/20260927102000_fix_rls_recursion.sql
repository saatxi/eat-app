-- Fix for infinite RLS recursion on group_members.
--
-- group_members_select_member queries group_members from within its own
-- policy, which Postgres rejects with "infinite recursion detected in
-- policy". The standard fix is a SECURITY DEFINER helper function: it runs
-- as its owner (postgres, which bypasses RLS), so the policy's subquery no
-- longer re-enters the table's own policies.
--
-- All membership checks across every policy are rewritten to go through
-- is_group_member(); owner checks go through is_group_owner(). This also
-- makes every policy shorter and uniform.

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

revoke all on function public.is_group_member(uuid) from public, anon;
revoke all on function public.is_group_owner(uuid) from public, anon;
grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.is_group_owner(uuid) to authenticated;

-- ── groups ───────────────────────────────────────────────────────────────

drop policy "groups_select_member" on public.groups;
drop policy "groups_update_owner" on public.groups;
drop policy "groups_delete_owner" on public.groups;

create policy "groups_select_member" on public.groups
  for select to authenticated
  using (public.is_group_member(groups.id));

create policy "groups_update_owner" on public.groups
  for update to authenticated
  using (public.is_group_owner(groups.id))
  with check (public.is_group_owner(groups.id));

create policy "groups_delete_owner" on public.groups
  for delete to authenticated
  using (public.is_group_owner(groups.id));

-- ── group_members ────────────────────────────────────────────────────────

drop policy "group_members_select_member" on public.group_members;
drop policy "group_members_insert_owner" on public.group_members;
drop policy "group_members_delete_owner_or_self" on public.group_members;

create policy "group_members_select_member" on public.group_members
  for select to authenticated
  using (public.is_group_member(group_members.group_id));

create policy "group_members_insert_owner" on public.group_members
  for insert to authenticated
  with check (public.is_group_owner(group_members.group_id));

create policy "group_members_delete_owner_or_self" on public.group_members
  for delete to authenticated
  using (
    user_id = auth.uid() or public.is_group_owner(group_members.group_id)
  );

-- ── invites ──────────────────────────────────────────────────────────────

drop policy "invites_select_member" on public.invites;

create policy "invites_select_member" on public.invites
  for select to authenticated
  using (public.is_group_member(invites.group_id));

-- ── shared data tables ───────────────────────────────────────────────────

drop policy "restaurants_select_member" on public.restaurants;
drop policy "restaurants_insert_member" on public.restaurants;
drop policy "restaurants_update_member" on public.restaurants;
drop policy "restaurants_delete_member" on public.restaurants;

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

drop policy "visits_select_member" on public.visits;
drop policy "visits_insert_member" on public.visits;
drop policy "visits_update_member" on public.visits;
drop policy "visits_delete_member" on public.visits;

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

drop policy "photos_select_member" on public.photos;
drop policy "photos_insert_member" on public.photos;
drop policy "photos_update_member" on public.photos;
drop policy "photos_delete_member" on public.photos;

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
