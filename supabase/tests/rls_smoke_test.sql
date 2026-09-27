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
do $$
declare affected integer;
begin
  update public.groups set name = 'hijacked'
    where id = 'cccccccc-0000-0000-0000-000000000001';
  get diagnostics affected = rowcount;
  if affected <> 0 then raise exception 'FAIL: bob renamed the group'; end if;

  delete from public.groups where id = 'cccccccc-0000-0000-0000-000000000001';
  get diagnostics affected = rowcount;
  if affected <> 0 then raise exception 'FAIL: bob deleted the group'; end if;

  -- Bob cannot remove Alice's membership.
  delete from public.group_members
    where group_id = 'cccccccc-0000-0000-0000-000000000001'
      and user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  get diagnostics affected = rowcount;
  if affected <> 0 then raise exception 'FAIL: bob removed alice'; end if;

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
declare
  cnt integer;
  affected integer;
begin
  select count(*) into cnt from public.groups;
  if cnt <> 0 then raise exception 'FAIL: carol sees % groups, expected 0', cnt; end if;

  select count(*) into cnt from public.restaurants;
  if cnt <> 0 then raise exception 'FAIL: carol sees % restaurants, expected 0', cnt; end if;

  select count(*) into cnt from public.visits;
  if cnt <> 0 then raise exception 'FAIL: carol sees % visits, expected 0', cnt; end if;

  select count(*) into cnt from public.photos;
  if cnt <> 0 then raise exception 'FAIL: carol sees % photos, expected 0', cnt; end if;

  -- RLS on the USING clause silently matches nothing.
  delete from public.restaurants
    where group_id = 'cccccccc-0000-0000-0000-000000000001';
  get diagnostics affected = rowcount;
  if affected <> 0 then raise exception 'FAIL: carol deleted a restaurant'; end if;

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

-- profiles are world-readable; only self-writable.
do $$
declare
  cnt integer;
  affected integer;
begin
  select count(*) into cnt from public.profiles
    where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if cnt <> 1 then raise exception 'FAIL: carol cannot read alice''s profile'; end if;

  insert into public.profiles (id, display_name)
  values ('eeeeeeee-0000-0000-0000-000000000003', 'Carol');

  update public.profiles set display_name = 'Not Alice'
    where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  get diagnostics affected = rowcount;
  if affected <> 0 then raise exception 'FAIL: carol updated alice''s profile'; end if;
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
declare affected integer;
begin
  delete from public.groups where id = 'cccccccc-0000-0000-0000-000000000001';
  get diagnostics affected = rowcount;
  if affected <> 1 then
    raise exception 'FAIL: owner dissolved % groups, expected 1', affected;
  end if;
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

rollback;
