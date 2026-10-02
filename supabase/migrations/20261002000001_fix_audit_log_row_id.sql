-- Fix the audit trigger's row_id for group_members rows.
--
-- private.log_change derived row_id from the 'id' or 'restaurant_id' column,
-- but group_members has neither — its key is (group_id, user_id) — so the
-- insert failed audit_log.row_id's NOT NULL constraint on every membership
-- change. Fall back to user_id as well. Recreating the function is enough;
-- the triggers already point at it.

create or replace function private.log_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rec jsonb := to_jsonb(coalesce(new, old));
  gid uuid := (rec ->> 'group_id')::uuid;
  rid uuid := coalesce(
    (rec ->> 'id')::uuid,
    (rec ->> 'user_id')::uuid,
    (rec ->> 'restaurant_id')::uuid
  );
begin
  insert into public.audit_log (group_id, actor_id, table_name, row_id, action)
  values (gid, auth.uid(), tg_table_name, rid, lower(tg_op));
  return coalesce(new, old);
end;
$$;

-- Trigger functions are system-invoked; keep them out of every client role.
revoke all on function private.log_change() from public, anon, authenticated;
