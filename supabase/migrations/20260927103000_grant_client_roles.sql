-- Table privileges for the client roles.
--
-- Tables created by migrations run as postgres, which does not carry the
-- dashboard's default privileges, so anon/authenticated end up with no
-- grants at all. Every table is granted to both roles; RLS is what actually
-- restricts them (enable row level security denies by default, and the
-- policies above decide the rest). No grants on private.join_attempts: it
-- stays reachable only through record_join_attempt().

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on
  public.profiles,
  public.groups,
  public.group_members,
  public.invites,
  public.restaurants,
  public.visits,
  public.photos
to anon, authenticated;
