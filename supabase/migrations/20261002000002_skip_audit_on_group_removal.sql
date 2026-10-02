-- Skip the audit insert for a group that is being removed.
--
-- When a group is deleted, the cascade reaches group_members, restaurant_groups
-- and the shared rows after the groups row is already gone, so logging those
-- cascaded deletes hit audit_log.group_id's foreign key. There is nothing
-- meaningful to record against a group that is being dissolved — its existing
-- audit rows cascade away with it — so the trigger returns early in that case.

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
  if gid is not null
    and not exists (select 1 from public.groups where id = gid)
  then
    return coalesce(new, old);
  end if;

  insert into public.audit_log (group_id, actor_id, table_name, row_id, action)
  values (gid, auth.uid(), tg_table_name, rid, lower(tg_op));
  return coalesce(new, old);
end;
$$;

revoke all on function private.log_change() from public, anon, authenticated;
