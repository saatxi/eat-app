-- group_tags was added in the 2026-09-29 groups schema "for organisation",
-- but no client ever wrote or read it, and this overhaul took the occasion to
-- drop everything unused rather than carry it forward. Its RLS policies and
-- grants are dropped along with it.
drop table if exists public.group_tags;
