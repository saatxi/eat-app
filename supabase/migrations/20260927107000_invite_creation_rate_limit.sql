-- Rate limiting for the create-invite Edge Function.
--
-- Mirror of the join rate limit (20260927101000_join_rate_limit.sql): the
-- function calls record_invite_attempt() before doing anything else, and the
-- RPC is SECURITY DEFINER because the attempts table must never be reachable by
-- clients — RLS is enabled on it with no policy, so only the function gets
-- through. An attempt is recorded on every call, so a script that mints and
-- discards tokens is throttled just like one that keeps them.

create table private.invite_attempts (
  user_id uuid not null references auth.users (id) on delete cascade,
  attempted_at timestamptz not null default now()
);

create index index_invite_attempts_user_time
  on private.invite_attempts (user_id, attempted_at);

-- No RLS policies: with RLS enabled and none, no client role can touch it.
alter table private.invite_attempts enable row level security;

create or replace function public.record_invite_attempt()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Sliding window: 20 invitations minted per user per hour. A person hands
  -- invites out one at a time, so this is generous for them and tight for a
  -- script; the ceiling also bounds how many live tokens a single account can
  -- keep in circulation.
  if (
    select count(*) from private.invite_attempts
    where user_id = auth.uid()
      and attempted_at > now() - interval '1 hour'
  ) >= 20 then
    raise exception 'invite_attempts_rate_limited';
  end if;

  insert into private.invite_attempts (user_id) values (auth.uid());

  -- Opportunistic cleanup of this user's stale rows.
  delete from private.invite_attempts
  where user_id = auth.uid()
    and attempted_at < now() - interval '1 day';
end;
$$;

revoke all on function public.record_invite_attempt() from public, anon;
grant execute on function public.record_invite_attempt() to authenticated;
