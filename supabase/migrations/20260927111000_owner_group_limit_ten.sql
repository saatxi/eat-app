-- Raise the owner-group cap from 2 to 10.
--
-- The cap is a single row in private.app_settings (owner_group_limit), so
-- raising it is just an UPDATE — no schema change, no app release: the trigger
-- (group_members_owner_cap) and the pre-validation RPC
-- (public.owner_group_limit()) both read this value at call time. This
-- migration makes the new value part of the schema's history, so a fresh
-- `db reset` ends up at 10 rather than 2.

insert into private.app_settings (key, value)
values ('owner_group_limit', '10')
on conflict (key) do update set value = excluded.value;

-- Keep the function's fallback (used only if the row ever goes missing) in
-- step with the new default. CREATE OR REPLACE preserves the existing grants,
-- so the authenticated EXECUTE grant from the original migration still holds.
create or replace function public.owner_group_limit()
returns integer
language sql
security definer
set search_path = ''
stable
as $$
  select coalesce(
    (select value::integer from private.app_settings where key = 'owner_group_limit'),
    10
  );
$$;
