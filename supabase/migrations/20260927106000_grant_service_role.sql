-- Service-role grants for the Edge Functions.
--
-- join-group and create-invite use a service-role client for their
-- privileged writes (adding a member, minting an invite, upserting the
-- profile). Tables created by migrations carry no default grants, so those
-- writes failed with a permission error even though service_role bypasses
-- RLS — RLS bypass does not imply table privileges.

grant select, insert, update, delete on
  public.profiles,
  public.groups,
  public.group_members,
  public.invites,
  public.restaurants,
  public.visits,
  public.photos
to service_role;
