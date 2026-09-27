-- Rate limiting for the join-group Edge Function.
--
-- The function calls record_join_attempt() before doing anything else; the
-- RPC is SECURITY DEFINER because the attempts table itself must not be
-- readable or writable by clients (RLS on it denies everyone), while the
-- function only exposes pass/fail. Attempts are recorded on every call, so
-- failed guesses count toward the limit too.

create schema if not exists private;

create table private.join_attempts (
  user_id uuid not null references auth.users (id) on delete cascade,
  attempted_at timestamptz not null default now()
);

create index index_join_attempts_user_time
  on private.join_attempts (user_id, attempted_at);

-- No RLS policies at all: with RLS enabled and no policy, no client role can
-- touch the table. Only the SECURITY DEFINER function reaches it.
alter table private.join_attempts enable row level security;

create or replace function public.record_join_attempt()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Sliding window: 10 attempts per user per 10 minutes.
  if (
    select count(*) from private.join_attempts
    where user_id = auth.uid()
      and attempted_at > now() - interval '10 minutes'
  ) >= 10 then
    raise exception 'join_attempts_rate_limited';
  end if;

  insert into private.join_attempts (user_id) values (auth.uid());

  -- Opportunistic cleanup of this user's stale rows.
  delete from private.join_attempts
  where user_id = auth.uid()
    and attempted_at < now() - interval '1 day';
end;
$$;

-- The function is callable by any authenticated user; everything else about
-- it is internal.
revoke all on function public.record_join_attempt() from public, anon;
grant execute on function public.record_join_attempt() to authenticated;
