-- RLS test suite — run against the remote database with
--   supabase db query --linked -f supabase/tests/rls_smoke_test.sql
--
-- The connection runs as postgres, so the test SETs ROLE to authenticated and
-- simulates each user's JWT claims with set_config() to exercise the policies
-- exactly as a real client would. rollback cleans up every row the test made.
--
-- Three identities, one group:
--   Alice  — owns the group, and authors its first restaurant/visit/photo.
--   Bob    — a plain member Alice invited.
--   Carol  — a stranger who belongs to nothing.
--
-- What it checks:
--   1. Alice, as the owner, sees exactly her group's rows.
--   2. Bob, once a member, sees the group and its rows, may add his own
--      (attributed to himself) but may not forge authorship, and may not
--      manage the group or its members.
--   3. Carol sees nothing, may write nothing into the group, and may not add
--      herself to it.
--   4. Only an owner may mint invites; no client may insert into invites.
--   5. profiles are world-readable but only self-writable.
--   6. The last owner cannot leave a group that still has members
--      (group_members_keep_owner); a solo owner can.
--   7. An owner dissolving the group cascades every shared row away.
--   8. Leaving when the leaver was the last member dissolves the group too
--      (group_members_dissolve_when_empty): a member leaving while others
--      remain is a plain leave, but the last member's leave removes the group
--      and cascades every shared row with it.
--   9. A user may own no more than the configured number of groups
--      (group_members_owner_cap, default 2); plain membership is unlimited.
--
-- Any violated expectation raises an exception and fails the run.

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
   '{"provider":"anon","providers":["anon"]}', '{}'),
  ('00000000-0000-0000-0000-000000000000',
   'bbbbbbbb-0000-0000-0000-000000000002',
   'authenticated', 'authenticated', 'rls-test-bob@example.com',
   crypt('x', gen_salt('bf')), now(), now(), now(),
   '{"provider":"anon","providers":["anon"]}', '{}'),
  ('00000000-0000-0000-0000-000000000000',
   'eeeeeeee-0000-0000-0000-000000000003',
   'authenticated', 'authenticated', 'rls-test-carol@example.com',
   crypt('x', gen_salt('bf')), now(), now(), now(),
   '{"provider":"anon","providers":["anon"]}', '{}');

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

insert into public.restaurants (
  id, group_id, name, "cuisineType", "priceRange", created_by
) values (
  'dddddddd-0000-0000-0000-000000000001',
  'cccccccc-0000-0000-0000-000000000001',
  'Alice place', 'japanese', 2,
  'aaaaaaaa-0000-0000-0000-000000000001'
);

insert into public.visits (
  id, group_id, restaurant_id, "visitDate", rating, "priceRange", created_by
) values (
  'ffffffff-0000-0000-0000-000000000001',
  'cccccccc-0000-0000-0000-000000000001',
  'dddddddd-0000-0000-0000-000000000001',
  1700000000000, 4, 2,
  'aaaaaaaa-0000-0000-0000-000000000001'
);

insert into public.photos (
  id, group_id, restaurant_id, position, storage_path, created_by
) values (
  '11111111-0000-0000-0000-000000000001',
  'cccccccc-0000-0000-0000-000000000001',
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

  select count(*) into cnt from public.visits;
  if cnt <> 1 then raise exception 'FAIL: alice sees % visits, expected 1', cnt; end if;

  select count(*) into cnt from public.photos;
  if cnt <> 1 then raise exception 'FAIL: alice sees % photos, expected 1', cnt; end if;

  select count(*) into cnt from public.group_members;
  if cnt <> 1 then raise exception 'FAIL: alice sees % members, expected 1', cnt; end if;
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

-- ── 3. Alice invites Bob ────────────────────────────────────────────────

insert into public.group_members (group_id, user_id, role)
values ('cccccccc-0000-0000-0000-000000000001',
  'bbbbbbbb-0000-0000-0000-000000000002', 'member');

-- ── 4. Bob's session (plain member) ─────────────────────────────────────

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
    id, group_id, name, "cuisineType", "priceRange", created_by
  ) values (
    'dddddddd-0000-0000-0000-000000000002',
    'cccccccc-0000-0000-0000-000000000001',
    'Bob place', 'italian', 1,
    'bbbbbbbb-0000-0000-0000-000000000002'
  );

  -- ...but may not forge authorship.
  begin
    insert into public.restaurants (
      id, group_id, name, "cuisineType", "priceRange", created_by
    ) values (
      'dddddddd-0000-0000-0000-000000000003',
      'cccccccc-0000-0000-0000-000000000001',
      'Forged', 'italian', 1,
      'aaaaaaaa-0000-0000-0000-000000000001'
    );
    raise exception 'FAIL: bob forged created_by';
  exception when insufficient_privilege or check_violation then
    null; -- expected
  end;
end;
$$;

-- Bob is a member, not an owner: he may not manage the group or its members.
-- The Management API (db query --linked) rejects `get diagnostics rowcount`,
-- so the no-op statements are verified by re-reading: the forbidden mutation
-- must have changed nothing.
do $$
declare cnt integer;
begin
  update public.groups set name = 'hijacked'
    where id = 'cccccccc-0000-0000-0000-000000000001';
  select count(*) into cnt from public.groups
    where id = 'cccccccc-0000-0000-0000-000000000001' and name = 'hijacked';
  if cnt <> 0 then raise exception 'FAIL: bob renamed the group'; end if;

  delete from public.groups where id = 'cccccccc-0000-0000-0000-000000000001';
  select count(*) into cnt from public.groups
    where id = 'cccccccc-0000-0000-0000-000000000001';
  if cnt <> 1 then raise exception 'FAIL: bob deleted the group'; end if;

  -- Bob cannot remove Alice's membership.
  delete from public.group_members
    where group_id = 'cccccccc-0000-0000-0000-000000000001'
      and user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  select count(*) into cnt from public.group_members
    where group_id = 'cccccccc-0000-0000-0000-000000000001'
      and user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if cnt <> 1 then raise exception 'FAIL: bob removed alice'; end if;

  -- Bob cannot add someone else either.
  begin
    insert into public.group_members (group_id, user_id, role)
    values ('cccccccc-0000-0000-0000-000000000001',
      'eeeeeeee-0000-0000-0000-000000000003', 'member');
    raise exception 'FAIL: bob added carol';
  exception when insufficient_privilege or check_violation then
    null; -- expected
  end;
end;
$$;

-- ── 5. Carol's session (a stranger) ─────────────────────────────────────

select set_config('request.jwt.claims',
  '{"sub":"eeeeeeee-0000-0000-0000-000000000003"}', true);

do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups;
  if cnt <> 0 then raise exception 'FAIL: carol sees % groups, expected 0', cnt; end if;

  select count(*) into cnt from public.restaurants;
  if cnt <> 0 then raise exception 'FAIL: carol sees % restaurants, expected 0', cnt; end if;

  select count(*) into cnt from public.visits;
  if cnt <> 0 then raise exception 'FAIL: carol sees % visits, expected 0', cnt; end if;

  select count(*) into cnt from public.photos;
  if cnt <> 0 then raise exception 'FAIL: carol sees % photos, expected 0', cnt; end if;

  -- RLS on the USING clause silently matches nothing. Whether the delete
  -- actually removed a row is verified as postgres below (Carol's own view
  -- hides the row either way).
  delete from public.restaurants
    where group_id = 'cccccccc-0000-0000-0000-000000000001';

  -- WITH CHECK policies reject an outright insert.
  begin
    insert into public.restaurants (
      id, group_id, name, "cuisineType", "priceRange", created_by
    ) values (
      'dddddddd-0000-0000-0000-000000000009',
      'cccccccc-0000-0000-0000-000000000001',
      'Carol intrusion', 'japanese', 2,
      'eeeeeeee-0000-0000-0000-000000000003'
    );
    raise exception 'FAIL: carol inserted into a group she is not in';
  exception when insufficient_privilege or check_violation then
    null; -- expected
  end;

  begin
    insert into public.group_members (group_id, user_id, role)
    values ('cccccccc-0000-0000-0000-000000000001',
      'eeeeeeee-0000-0000-0000-000000000003', 'member');
    raise exception 'FAIL: carol added herself';
  exception when insufficient_privilege or check_violation then
    null; -- expected
  end;
end;
$$;

-- Verify Carol could not delete Alice's data. Count as postgres: Carol's own
-- view hides the row either way, so her session could not tell the difference.
reset role;
do $$
declare cnt integer;
begin
  select count(*) into cnt from public.restaurants
    where id = 'dddddddd-0000-0000-0000-000000000001';
  if cnt <> 1 then raise exception 'FAIL: carol deleted a restaurant'; end if;
end;
$$;

-- profiles are world-readable; only self-writable.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"eeeeeeee-0000-0000-0000-000000000003"}', true);

do $$
declare cnt integer;
begin
  select count(*) into cnt from public.profiles
    where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if cnt <> 1 then raise exception 'FAIL: carol cannot read alice''s profile'; end if;

  insert into public.profiles (id, display_name)
  values ('eeeeeeee-0000-0000-0000-000000000003', 'Carol');

  update public.profiles set display_name = 'Not Alice'
    where id = 'aaaaaaaa-0000-0000-0000-000000000001';
end;
$$;

-- The update was a no-op: Alice's profile is unchanged. Count as postgres.
reset role;
do $$
declare cnt integer;
begin
  select count(*) into cnt from public.profiles
    where id = 'aaaaaaaa-0000-0000-0000-000000000001'
      and display_name = 'Not Alice';
  if cnt <> 0 then raise exception 'FAIL: carol updated alice''s profile'; end if;
end;
$$;

-- ── 6. The last owner may not leave a group that still has members ───────

select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', true);

do $$
declare blocked boolean := false;
begin
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
end;
$$;

-- ── 7. An owner dissolves the group; the cascade clears every row ────────

do $$
declare cnt integer;
begin
  delete from public.groups where id = 'cccccccc-0000-0000-0000-000000000001';
  select count(*) into cnt from public.groups
    where id = 'cccccccc-0000-0000-0000-000000000001';
  if cnt <> 0 then raise exception 'FAIL: owner dissolution left the group'; end if;
end;
$$;

-- Back to postgres to count without any RLS filter.
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

  select count(*) into cnt from public.restaurants
    where group_id = 'cccccccc-0000-0000-0000-000000000001';
  if cnt <> 0 then raise exception 'FAIL: restaurants survived dissolution'; end if;

  select count(*) into cnt from public.visits
    where group_id = 'cccccccc-0000-0000-0000-000000000001';
  if cnt <> 0 then raise exception 'FAIL: visits survived dissolution'; end if;

  select count(*) into cnt from public.photos
    where group_id = 'cccccccc-0000-0000-0000-000000000001';
  if cnt <> 0 then raise exception 'FAIL: photos survived dissolution'; end if;
end;
$$;

-- ── 8. The last member leaving dissolves the group ───────────────────────
--
-- A fresh two-member group: Bob leaves first while Alice remains — a plain
-- leave, the group survives. Then Alice, now the last member, leaves and the
-- group (and the shared row it carried) is dissolved by
-- group_members_dissolve_when_empty.

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', true);

insert into public.groups (id, name, created_by)
values ('cccccccc-0000-0000-0000-000000000002', 'RLS last-member test group',
  'aaaaaaaa-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id, role)
values ('cccccccc-0000-0000-0000-000000000002',
  'aaaaaaaa-0000-0000-0000-000000000001', 'owner');

insert into public.group_members (group_id, user_id, role)
values ('cccccccc-0000-0000-0000-000000000002',
  'bbbbbbbb-0000-0000-0000-000000000002', 'member');

insert into public.restaurants (
  id, group_id, name, "cuisineType", "priceRange", created_by
) values (
  'dddddddd-0000-0000-0000-00000000000a',
  'cccccccc-0000-0000-0000-000000000002',
  'Shared place', 'japanese', 2,
  'aaaaaaaa-0000-0000-0000-000000000001'
);

-- Bob (a member, not the last) leaves: the group must survive with Alice.
select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-0000-0000-0000-000000000002"}', true);

delete from public.group_members
  where group_id = 'cccccccc-0000-0000-0000-000000000002'
    and user_id = 'bbbbbbbb-0000-0000-0000-000000000002';

-- Count as postgres: RLS would filter the group out of the leaver's own view
-- the moment their membership is gone, hiding the very row that must survive.
reset role;

do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups
    where id = 'cccccccc-0000-0000-0000-000000000002';
  if cnt <> 1 then
    raise exception 'FAIL: group died when a non-last member left';
  end if;

  select count(*) into cnt from public.group_members
    where group_id = 'cccccccc-0000-0000-0000-000000000002';
  if cnt <> 1 then
    raise exception 'FAIL: % members remain after bob left, expected 1', cnt;
  end if;
end;
$$;

-- Alice is now the last member. Leaving dissolves the group, cascading the
-- restaurant away with it.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', true);

delete from public.group_members
  where group_id = 'cccccccc-0000-0000-0000-000000000002'
    and user_id = 'aaaaaaaa-0000-0000-0000-000000000001';

reset role;

do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups
    where id = 'cccccccc-0000-0000-0000-000000000002';
  if cnt <> 0 then
    raise exception 'FAIL: group survived the last member''s leave';
  end if;

  select count(*) into cnt from public.group_members
    where group_id = 'cccccccc-0000-0000-0000-000000000002';
  if cnt <> 0 then
    raise exception 'FAIL: members survived the last member''s leave';
  end if;

  select count(*) into cnt from public.restaurants
    where group_id = 'cccccccc-0000-0000-0000-000000000002';
  if cnt <> 0 then
    raise exception 'FAIL: restaurants survived the last member''s leave';
  end if;
end;
$$;

-- ── 9. A user may own no more than the configured number of groups ────────
--
-- The owner cap (group_members_owner_cap) counts owner memberships, not
-- memberships. Alice's earlier groups were dissolved in sections 7 and 8, so
-- her owner count is 0 when this section starts. To reach the cap she must
-- own the configured limit's worth of groups; each "create" is the groups row
-- plus her owner membership, exactly like the app does. Then a third create
-- is refused, while joining other people's groups as a member is never
-- limited.

-- 9a. Alice's current owner count and the configured cap.
reset role;
do $$
declare
  cap integer;
  owned integer;
begin
  select public.owner_group_limit() into cap;

  select count(*) into owned
  from public.group_members
  where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'
    and role = 'owner';
  if owned <> 0 then
    raise exception 'FAIL: alice starts the cap test with % owned groups, expected 0', owned;
  end if;

  if cap <> 2 then
    raise exception 'FAIL: owner_group_limit() = %, expected 2', cap;
  end if;
end;
$$;

-- 9b. Alice creates the cap's worth of groups (2), each as owner — allowed.
-- This is exactly the app's create path: the create_owned_group RPC (the
-- client no longer does two inserts). It inserts the groups row and the owner
-- membership in one transaction.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', true);

select public.create_owned_group(
  'cccccccc-0000-0000-0000-000000000003', 'RLS cap group 1'
);
select public.create_owned_group(
  'cccccccc-0000-0000-0000-000000000004', 'RLS cap group 2'
);

-- 9c. A third group of her own is refused by the cap trigger (raised from the
-- RPC, en route inside the same transaction). The rollback also proves the
-- groups row did not linger as an orphan.
do $$
declare blocked boolean := false;
begin
  begin
    select public.create_owned_group(
      'cccccccc-0000-0000-0000-000000000005', 'RLS cap group 3'
    );
  exception when others then
    if sqlerrm like '%owner_group_limit_reached%' then
      blocked := true;
    else
      raise;
    end if;
  end;

  if not blocked then
    raise exception 'FAIL: the owner cap let alice own a third group';
  end if;
end;
$$;

-- The refused RPC rolled its whole transaction back — no orphan groups row.
reset role;
do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups
    where id = 'cccccccc-0000-0000-0000-000000000005';
  if cnt <> 0 then
    raise exception 'FAIL: the rejected third group left an orphan row';
  end if;
end;
$$;

-- The refused group's row was rolled back by the exception, so Alice still
-- owns exactly the cap (2). Count as postgres: the ownership count is the
-- authoritative invariant, and it must hold exactly.
reset role;
do $$
declare cnt integer;
begin
  select count(*) into cnt from public.group_members
    where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'
      and role = 'owner';
  if cnt <> 2 then
    raise exception 'FAIL: alice owns %, expected 2 after the cap rejected the third', cnt;
  end if;
end;
$$;

-- 9d. Membership as a plain member is unlimited: Alice's adding Bob as a
-- member of both of her new groups is unaffected by the cap — the cap counts
-- only owner rows, and Bob's own (future) memberships are never counted
-- against anyone. Bob is not an owner of these, so inserting him needs Alice,
-- who is.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', true);

insert into public.group_members (group_id, user_id, role)
values ('cccccccc-0000-0000-0000-000000000003',
  'bbbbbbbb-0000-0000-0000-000000000002', 'member');
insert into public.group_members (group_id, user_id, role)
values ('cccccccc-0000-0000-0000-000000000004',
  'bbbbbbbb-0000-0000-0000-000000000002', 'member');

-- back to postgres for the final read-only assertions.
reset role;
do $$
declare cnt integer;
begin
  select count(*) into cnt from public.group_members
    where user_id = 'bbbbbbbb-0000-0000-0000-000000000002'
      and role = 'member';
  if cnt <> 2 then
    raise exception 'FAIL: bob joined % groups as a member, expected 2 (unlimited)', cnt;
  end if;
end;
$$;

rollback;
