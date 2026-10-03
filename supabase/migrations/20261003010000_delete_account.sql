-- EatApp account deletion — the data cleanup behind the "Delete profile"
-- action.
--
-- Deleting the auth.users row cascades most of a user's footprint (profiles,
-- the groups they created, their group_members, invites, rate attempts). But
-- four shared tables reference auth.users with no ON DELETE action —
-- restaurants, visits, photos and restaurant_groups, all keyed on created_by —
-- and would block the delete while the user had authored any shared row.
--
-- So the delete-account Edge Function, running as the service role, calls this
-- function to clear the public rows first and then deletes the auth user, whose
-- cascade clears the rest.
--
-- SECURITY DEFINER: the cleanup runs with owner rights so it bypasses RLS and
-- removes rows regardless of the caller's policies. Only the service role may
-- execute it.

create or replace function public.delete_account_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- The groups the user created dissolve entirely, taking their members and
  -- restaurant links with them (the cascade deletes the group row first, so the
  -- keep-owner guard sees no group and lets the members go).
  delete from public.groups where created_by = p_user_id;

  -- A group the user is the last owner of — a co-owner of someone else's group
  -- — also dissolves, or the membership delete below would be refused by the
  -- keep-owner guard.
  delete from public.groups g
  using public.group_members gm
  where gm.group_id = g.id
    and gm.user_id = p_user_id
    and gm.role = 'owner'
    and not exists (
      select 1 from public.group_members other
      where other.group_id = g.id
        and other.user_id <> p_user_id
        and other.role = 'owner'
    );

  -- Rows the user authored in other people's groups: their created_by foreign
  -- keys have no cascade, so the auth user could not be removed while they
  -- remain. Deleting a restaurant cascades its visits and photos.
  delete from public.restaurants where created_by = p_user_id;
  delete from public.visits where created_by = p_user_id;
  delete from public.photos where created_by = p_user_id;
  delete from public.restaurant_groups where created_by = p_user_id;

  -- Membership in other people's groups; the dissolve-when-empty trigger
  -- removes a group left with no members.
  delete from public.group_members where user_id = p_user_id;

  -- The profile row itself.
  delete from public.profiles where id = p_user_id;
end;
$$;

revoke all on function public.delete_account_data(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_account_data(uuid) to service_role;
