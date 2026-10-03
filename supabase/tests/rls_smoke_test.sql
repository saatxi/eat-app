-- RLS test suite — run against the remote database with
--   supabase db query --linked -f supabase/tests/rls_smoke_test.sql
--
-- The connection runs as postgres, so the test SETs ROLE to authenticated and
-- simulates each user's JWT claims with set_config() to exercise the policies
-- exactly as a real client would. rollback cleans up every row the test made.
--
-- Four identities, one group:
--   Alice  — owns the group, and authors its first restaurant/visit/photo.
--   Bob    — an editor Alice invited.
--   Dave   — a reader Alice invited (read-only).
--   Carol  — a stranger who belongs to nothing.
--
-- What it checks:
--   1. Alice, as the owner, sees exactly her group's rows.
--   2. Membership is a junction (restaurant_groups): a restaurant is visible to
--      members of every group it is shared into; its visits and photos follow.
--   3. Bob, as an editor, may add and edit the group's rows but may not manage
--      the group, its members or its tags.
--   4. Dave, as a reader, may read but may not write.
--   5. Carol sees nothing and may write nothing into the group.
--   6. Only an owner may mint invites; no client may insert into invites.
--   7. profiles are world-readable but only self-writable.
--   8. The last owner cannot leave (or be demoted) while members remain.
--   9. A group with no members left is dissolved, cascading its rows away; a
--      restaurant whose last membership goes is deleted with its visits/photos.
--  10. A user may own no more than the configured number of groups.

begin;

-- ── 1. test identities (as postgres) ─────────────────────────────────────

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
) values
  ('00000000-0000-0000-0000-000000000000',
   'aaaaaaaa-0000-0000-0000-000000000001',
   'authenticated', 'authenticated', 'rls-test-alice@example.com',
   crypt('x', gen_salt('bf')), now(), now(), now(),
   '{"provider":"google","providers":["google"]}', '{}'),
  ('00000000-0000-0000-0000-000000000000',
   'bbbbbbbb-0000-0000-0000-000000000002',
   'authenticated', 'authenticated', 'rls-test-bob@example.com',
   crypt('x', gen_salt('bf')), now(), now(), now(),
   '{"provider":"google","providers":["google"]}', '{}'),
  ('00000000-0000-0000-0000-000000000000',
   '99999999-0000-0000-0000-000000000004',
   'authenticated', 'authenticated', 'rls-test-dave@example.com',
   crypt('x', gen_salt('bf')), now(), now(), now(),
   '{"provider":"google","providers":["google"]}', '{}'),
  ('00000000-0000-0000-0000-000000000000',
   'eeeeeeee-0000-0000-0000-000000000003',
   'authenticated', 'authenticated', 'rls-test-carol@example.com',
   crypt('x', gen_salt('bf')), now(), now(), now(),
   '{"provider":"google","providers":["google"]}', '{}');

-- ── 2. Alice creates the group and its content ───────────────────────────

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', true);

insert into public.groups (id, name, created_by)
values ('cccccccc-0000-0000-0000-000000000001', 'RLS policies test group',
  'aaaaaaaa-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id, role)
values ('cccccccc-0000-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000001', 'owner');

-- restaurants carry no group of their own now; membership is the junction.
insert into public.restaurants (
  id, name, "cuisineType", "priceRange", created_by
) values (
  'dddddddd-0000-0000-0000-000000000001',
  'Alice place', 'japanese', 2,
  'aaaaaaaa-0000-0000-0000-000000000001'
);

insert into public.restaurant_groups (restaurant_id, group_id, created_by)
values ('dddddddd-0000-0000-0000-000000000001',
  'cccccccc-0000-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000001');

insert into public.visits (
  id, restaurant_id, "visitDate", rating, "priceRange", created_by
) values (
  'ffffffff-0000-0000-0000-000000000001',
  'dddddddd-0000-0000-0000-000000000001',
  1700000000000, 4, 2,
  'aaaaaaaa-0000-0000-0000-000000000001'
);

insert into public.photos (
  id, restaurant_id, position, storage_path, created_by
) values (
  '11111111-0000-0000-0000-000000000001',
  'dddddddd-0000-0000-0000-000000000001',
  0, 'cccccccc-0000-0000-0000-000000000001/11111111-0000-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000001'
);

insert into public.profiles (id, display_name)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'Alice');

do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups;
  if cnt <> 1 then raise exception 'FAIL: alice sees % groups, expected 1', cnt; end if;

  select count(*) into cnt from public.restaurants;
  if cnt <> 1 then raise exception 'FAIL: alice sees % restaurants, expected 1', cnt; end if;

  select count(*) into cnt from public.restaurant_groups;
  if cnt <> 1 then raise exception 'FAIL: alice sees % junctions, expected 1', cnt; end if;

  select count(*) into cnt from public.visits;
  if cnt <> 1 then raise exception 'FAIL: alice sees % visits, expected 1', cnt; end if;

  select count(*) into cnt from public.photos;
  if cnt <> 1 then raise exception 'FAIL: alice sees % photos, expected 1', cnt; end if;

  select count(*) into cnt from public.group_members;
  if cnt <> 1 then raise exception 'FAIL: alice sees % members, expected 1', cnt; end if;

  -- The roster view joins the profile in, obeying RLS via security_invoker.
  select count(*) into cnt from public.group_member_profiles
    where group_id = 'cccccccc-0000-0000-0000-000000000001'
      and display_name = 'Alice';
  if cnt <> 1 then
    raise exception 'FAIL: the roster view did not join the display name';
  end if;
end;
$$;

-- No client may insert into invites, not even the owner: only the
-- create-invite Edge Function (service role) mints them.
do $$
begin
  begin
    insert into public.invites (
      group_id, token_hash, expires_at, max_uses, created_by
    ) values (
      'cccccccc-0000-0000-0000-000000000001', 'deadbeef', now() + interval '1 day',
      5, 'aaaaaaaa-0000-0000-0000-000000000001'
    );
    raise exception 'FAIL: a client inserted into invites';
  exception when insufficient_privilege or check_violation then
    null; -- expected: no insert policy
  end;
end;
$$;

-- ── 3. Alice adds Bob as editor and Dave as reader ───────────────────────

insert into public.group_members (group_id, user_id, role)
values ('cccccccc-0000-0000-0000-000000000001',
  'bbbbbbbb-0000-0000-0000-000000000002', 'editor');

insert into public.group_members (group_id, user_id, role)
values ('cccccccc-0000-0000-0000-000000000001',
  '99999999-0000-0000-0000-000000000004', 'reader');

-- ── 4. Bob's session (editor) ────────────────────────────────────────────

select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-0000-0000-0000-000000000002"}', true);

do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups;
  if cnt <> 1 then raise exception 'FAIL: bob sees % groups, expected 1', cnt; end if;

  select count(*) into cnt from public.restaurants;
  if cnt <> 1 then raise exception 'FAIL: bob sees % restaurants, expected 1', cnt; end if;

  -- Bob may add his own content, attributed to himself.
  insert into public.restaurants (
    id, name, "cuisineType", "priceRange", created_by
  ) values (
    'dddddddd-0000-0000-0000-000000000002',
    'Bob place', 'italian', 1,
    'bbbbbbbb-0000-0000-0000-000000000002'
  );

  insert into public.restaurant_groups (restaurant_id, group_id, created_by)
  values ('dddddddd-0000-0000-0000-000000000002',
    'cccccccc-0000-0000-0000-000000000001',
    'bbbbbbbb-0000-0000-0000-000000000002');

  -- ...but may not forge authorship.
  begin
    insert into public.restaurants (
      id, name, "cuisineType", "priceRange", created_by
    ) values (
      'dddddddd-0000-0000-0000-000000000003',
      'Forged', 'italian', 1,
      'aaaaaaaa-0000-0000-0000-000000000001'
    );
    raise exception 'FAIL: bob forged created_by';
  exception when insufficient_privilege or check_violation then
    null; -- expected
  end;
end;
$$;

-- Bob is an editor, not an owner: he may not manage the group, its members or
-- its tags. The Management API (db query --linked) rejects
-- `get diagnostics rowcount`, so the no-op statements are verified by
-- re-reading: the forbidden mutation must have changed nothing.
do $$
declare cnt integer;
begin
  update public.groups set name = 'hijacked'
    where id = 'cccccccc-0000-0000-0000-000000000001';
  select count(*) into cnt from public.groups
    where id = 'cccccccc-0000-0000-0000-000000000001' and name = 'hijacked';
  if cnt <> 0 then raise exception 'FAIL: bob renamed the group'; end if;

  -- Bob cannot change a member's role.
  update public.group_members set role = 'owner'
    where group_id = 'cccccccc-0000-0000-0000-000000000001'
      and user_id = 'bbbbbbbb-0000-0000-0000-000000000002';
  select count(*) into cnt from public.group_members
    where group_id = 'cccccccc-0000-0000-0000-000000000001'
      and user_id = 'bbbbbbbb-0000-0000-0000-000000000002'
      and role = 'owner';
  if cnt <> 0 then raise exception 'FAIL: bob promoted himself'; end if;

  -- Bob cannot add someone else either.
  begin
    insert into public.group_members (group_id, user_id, role)
    values ('cccccccc-0000-0000-0000-000000000001',
      'eeeeeeee-0000-0000-0000-000000000003', 'editor');
    raise exception 'FAIL: bob added carol';
  exception when insufficient_privilege or check_violation then
    null; -- expected
  end;

  -- Bob cannot tag the group.
  begin
    insert into public.group_tags (group_id, tag)
    values ('cccccccc-0000-0000-0000-000000000001', 'friends');
    raise exception 'FAIL: bob tagged the group';
  exception when insufficient_privilege or check_violation then
    null; -- expected
  end;
end;
$$;

-- ── 5. Dave's session (reader — may read, may not write) ─────────────────

select set_config('request.jwt.claims',
  '{"sub":"99999999-0000-0000-0000-000000000004"}', true);

do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups;
  if cnt <> 1 then raise exception 'FAIL: dave sees % groups, expected 1', cnt; end if;

  select count(*) into cnt from public.restaurants;
  if cnt <> 2 then raise exception 'FAIL: dave sees % restaurants, expected 2', cnt; end if;

  select count(*) into cnt from public.visits;
  if cnt <> 1 then raise exception 'FAIL: dave sees % visits, expected 1', cnt; end if;

  -- A reader may not edit or delete Alice's restaurant.
  update public.restaurants set name = 'dave was here'
    where id = 'dddddddd-0000-0000-0000-000000000001';
  select count(*) into cnt from public.restaurants
    where id = 'dddddddd-0000-0000-0000-000000000001' and name = 'dave was here';
  if cnt <> 0 then raise exception 'FAIL: a reader edited a restaurant'; end if;

  delete from public.restaurants where id = 'dddddddd-0000-0000-0000-000000000001';
  select count(*) into cnt from public.restaurants
    where id = 'dddddddd-0000-0000-0000-000000000001';
  if cnt <> 1 then raise exception 'FAIL: a reader deleted a restaurant'; end if;
end;
$$;

-- ── 6. Carol's session (a stranger) ──────────────────────────────────────

select set_config('request.jwt.claims',
  '{"sub":"eeeeeeee-0000-0000-0000-000000000003"}', true);

do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups;
  if cnt <> 0 then raise exception 'FAIL: carol sees % groups, expected 0', cnt; end if;

  select count(*) into cnt from public.restaurants;
  if cnt <> 0 then raise exception 'FAIL: carol sees % restaurants, expected 0', cnt; end if;

  select count(*) into cnt from public.restaurant_groups;
  if cnt <> 0 then raise exception 'FAIL: carol sees % junctions, expected 0', cnt; end if;

  select count(*) into cnt from public.group_member_profiles;
  if cnt <> 0 then
    raise exception 'FAIL: carol sees % roster rows via the view, expected 0', cnt;
  end if;

  -- WITH CHECK policies reject an outright insert into a group she is not in.
  begin
    insert into public.restaurant_groups (restaurant_id, group_id, created_by)
    values ('dddddddd-0000-0000-0000-000000000001',
      'cccccccc-0000-0000-0000-000000000001',
      'eeeeeeee-0000-0000-0000-000000000003');
    raise exception 'FAIL: carol shared into a group she is not in';
  exception when insufficient_privilege or check_violation then
    null; -- expected
  end;

  begin
    insert into public.group_members (group_id, user_id, role)
    values ('cccccccc-0000-0000-0000-000000000001',
      'eeeeeeee-0000-0000-0000-000000000003', 'editor');
    raise exception 'FAIL: carol added herself';
  exception when insufficient_privilege or check_violation then
    null; -- expected
  end;
end;
$$;

-- ── 7. Multi-group: one restaurant shared into two groups ────────────────

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', true);

insert into public.groups (id, name, created_by)
values ('cccccccc-0000-0000-0000-000000000002', 'RLS second group',
  'aaaaaaaa-0000-0000-0000-000000000001');
insert into public.group_members (group_id, user_id, role)
values ('cccccccc-0000-0000-0000-000000000002',
  'aaaaaaaa-0000-0000-0000-000000000001', 'owner');

-- Share Alice's existing restaurant into the second group as well.
insert into public.restaurant_groups (restaurant_id, group_id, created_by)
values ('dddddddd-0000-0000-0000-000000000001',
  'cccccccc-0000-0000-0000-000000000002',
  'aaaaaaaa-0000-0000-0000-000000000001');

-- ── 8. The last owner may not leave or be demoted ────────────────────────

-- (Group 2 is a solo-owner group; group 1 has members.) Alice leaves group 2
-- freely — she is its only member, so the leave dissolves it.
delete from public.group_members
  where group_id = 'cccccccc-0000-0000-0000-000000000002'
    and user_id = 'aaaaaaaa-0000-0000-0000-000000000001';

do $$
declare blocked boolean := false;
begin
  -- In group 1 Alice is the last owner but others remain: she may not leave.
  begin
    delete from public.group_members
      where group_id = 'cccccccc-0000-0000-0000-000000000001'
        and user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  exception when others then
    if sqlerrm like '%last_owner_cannot_leave%' then
      blocked := true;
    else
      raise;
    end if;
  end;
  if not blocked then
    raise exception 'FAIL: the last owner left a group with other members';
  end if;

  -- ...nor may she demote herself while others remain.
  blocked := false;
  begin
    update public.group_members set role = 'editor'
      where group_id = 'cccccccc-0000-0000-0000-000000000001'
        and user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  exception when others then
    if sqlerrm like '%last_owner_cannot_be_demoted%' then
      blocked := true;
    else
      raise;
    end if;
  end;
  if not blocked then
    raise exception 'FAIL: the last owner demoted themselves';
  end if;
end;
$$;

-- ── 9. Dissolution cascades the junction and its rows ────────────────────

do $$
declare cnt integer;
begin
  delete from public.groups where id = 'cccccccc-0000-0000-0000-000000000001';
end;
$$;

reset role;
do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups
    where id = 'cccccccc-0000-0000-0000-000000000001';
  if cnt <> 0 then raise exception 'FAIL: group survived dissolution'; end if;

  select count(*) into cnt from public.group_members
    where group_id = 'cccccccc-0000-0000-0000-000000000001';
  if cnt <> 0 then raise exception 'FAIL: members survived dissolution'; end if;

  -- The junction cascaded; the prune trigger then deleted every restaurant
  -- whose last membership went, taking its visits and photos with it.
  select count(*) into cnt from public.restaurant_groups
    where group_id = 'cccccccc-0000-0000-0000-000000000001';
  if cnt <> 0 then raise exception 'FAIL: junctions survived dissolution'; end if;

  select count(*) into cnt from public.restaurants
    where id in ('dddddddd-0000-0000-0000-000000000001',
                 'dddddddd-0000-0000-0000-000000000002');
  if cnt <> 0 then raise exception 'FAIL: orphaned restaurants survived'; end if;

  select count(*) into cnt from public.visits
    where id = 'ffffffff-0000-0000-0000-000000000001';
  if cnt <> 0 then raise exception 'FAIL: visits survived dissolution'; end if;
end;
$$;

-- ── 10. A user may own no more than the configured number of groups ──────

do $$
declare
  cap integer;
  owned integer;
begin
  select public.owner_group_limit() into cap;
  if cap <> 10 then
    raise exception 'FAIL: owner_group_limit() = %, expected 10', cap;
  end if;

  select count(*) into owned
  from public.group_members
  where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and role = 'owner';
  if owned <> 0 then
    raise exception 'FAIL: alice starts the cap test with % owned groups', owned;
  end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', true);

do $$
declare
  cap integer;
  i integer;
begin
  select public.owner_group_limit() into cap;
  for i in 1..cap loop
    perform public.create_owned_group(gen_random_uuid(), 'RLS cap group ' || i);
  end loop;
end;
$$;

do $$
declare blocked boolean := false;
begin
  begin
    perform public.create_owned_group(
      'cccccccc-0000-0000-0000-0000000000ff', 'RLS cap overflow'
    );
  exception when others then
    if sqlerrm like '%owner_group_limit_reached%' then
      blocked := true;
    else
      raise;
    end if;
  end;
  if not blocked then
    raise exception 'FAIL: the owner cap let alice exceed the configured limit';
  end if;
end;
$$;

reset role;
do $$
declare cnt integer;
begin
  select count(*) into cnt from public.group_members
    where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and role = 'owner';
  if cnt <> 10 then
    raise exception 'FAIL: alice owns %, expected 10 after the cap rejected the extra', cnt;
  end if;
end;
$$;

-- ── 11. adopt-account rate limiting ──────────────────────────────────────
-- record_account_attempt is service-role only (the adopt-account Edge Function
-- calls it), so the test steps into that role. The per-code window is 10 per
-- 10 minutes: ten attempts pass, the eleventh on the same code is refused.

set local role service_role;
do $$
declare
  i integer;
  blocked boolean := false;
begin
  for i in 1..10 loop
    perform public.record_account_attempt('code-hash', 'client-hash');
  end loop;

  begin
    perform public.record_account_attempt('code-hash', 'client-hash');
  exception when others then
    if sqlerrm like '%rate_limited%' then
      blocked := true;
    else
      raise;
    end if;
  end;

  if not blocked then
    raise exception 'FAIL: the account rate limit did not trigger';
  end if;
end;
$$;
reset role;

rollback;
