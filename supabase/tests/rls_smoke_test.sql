-- RLS smoke test — run against the remote database with
--   supabase db query --linked -f supabase/tests/rls_smoke_test.sql
--
-- The connection runs as postgres, so the test SETs ROLE to authenticated
-- and simulates each user's JWT claims with set_config() to exercise the
-- policies exactly as a real client would.
--
-- Structure: everything that needs postgres privileges (creating auth.users
-- rows) happens first; the transaction then switches to authenticated and
-- stays there until the end. rollback cleans up every row the test made.
--
-- Scenario:
--   1. Two test identities in auth.users (Alice, Bob).
--   2. As Alice: create a group, become owner, insert a restaurant; verify
--      she sees exactly her own rows.
--   3. As Bob (not a member): verify he sees nothing and cannot write to
--      Alice's group or add himself to it.
--
-- Any violated expectation raises an exception and fails the run.

begin;

-- ── 1. test identities (as postgres) ─────────────────────────────────────

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
) values (
  '00000000-0000-0000-0000-000000000000',
  'aaaaaaaa-0000-0000-0000-000000000001',
  'authenticated', 'authenticated', 'rls-test-alice@example.com',
  crypt('x', gen_salt('bf')), now(), now(), now(),
  '{"provider":"anon","providers":["anon"]}', '{}'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
) values (
  '00000000-0000-0000-0000-000000000000',
  'bbbbbbbb-0000-0000-0000-000000000002',
  'authenticated', 'authenticated', 'rls-test-bob@example.com',
  crypt('x', gen_salt('bf')), now(), now(), now(),
  '{"provider":"anon","providers":["anon"]}', '{}'
);

-- ── 2. Alice's session ───────────────────────────────────────────────────

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', true);

insert into public.groups (id, name, created_by)
values ('cccccccc-0000-0000-0000-000000000001', 'RLS test group',
  'aaaaaaaa-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id, role)
values ('cccccccc-0000-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000001', 'owner');

insert into public.restaurants (
  id, group_id, name, "cuisineType", "priceRange", created_by
) values (
  'dddddddd-0000-0000-0000-000000000001',
  'cccccccc-0000-0000-0000-000000000001',
  'Test place', 'japanese', 2,
  'aaaaaaaa-0000-0000-0000-000000000001'
);

do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups;
  if cnt <> 1 then
    raise exception 'FAIL: alice sees % groups, expected 1', cnt;
  end if;

  select count(*) into cnt from public.restaurants;
  if cnt <> 1 then
    raise exception 'FAIL: alice sees % restaurants, expected 1', cnt;
  end if;
end;
$$;

-- ── 3. Bob's session (not a member) ──────────────────────────────────────

select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-0000-0000-0000-000000000002"}', true);

do $$
declare cnt integer;
begin
  select count(*) into cnt from public.groups;
  if cnt <> 0 then
    raise exception 'FAIL: bob sees % groups, expected 0', cnt;
  end if;

  select count(*) into cnt from public.restaurants;
  if cnt <> 0 then
    raise exception 'FAIL: bob sees % restaurants, expected 0', cnt;
  end if;

  begin
    insert into public.restaurants (
      id, group_id, name, "cuisineType", "priceRange", created_by
    ) values (
      'dddddddd-0000-0000-0000-000000000002',
      'cccccccc-0000-0000-0000-000000000001',
      'Bob intrusion', 'japanese', 2,
      'bbbbbbbb-0000-0000-0000-000000000002'
    );
    raise exception 'FAIL: bob inserted into a group he does not belong to';
  exception when insufficient_privilege or check_violation then
    null; -- expected: RLS blocked it
  end;

  begin
    insert into public.group_members (group_id, user_id, role)
    values ('cccccccc-0000-0000-0000-000000000001',
      'bbbbbbbb-0000-0000-0000-000000000002', 'member');
    raise exception 'FAIL: bob added himself to a group';
  exception when insufficient_privilege or check_violation then
    null; -- expected: RLS blocked it
  end;
end;
$$;

rollback;
