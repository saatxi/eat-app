-- Remove the rows the e2e and smoke tests left in the project.
--
-- Order matters: the anonymous e2e users are matched through their membership,
-- and deleting the groups below cascades group_members away — so the
-- membership-based user delete must run first, while the memberships still exist.
delete from auth.users where is_sso_user = false and email is null
  and created_at > now() - interval '1 hour'
  and id in (
    select user_id from public.group_members gm
    join public.groups g on g.id = gm.group_id
    where g.name like 'RLS %test group'
  );
delete from auth.users where email like 'rls-test-%@example.com';
delete from public.groups where name like 'RLS %test group'
  or name like 'RLS %test group %'
  or name like 'RLS cap group %';
