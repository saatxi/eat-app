-- EatApp — keep a membership's tombstone so a removal reaches every member.
--
-- The prune trigger used to fire on every junction write, and deleted a
-- restaurant as soon as its last *live* membership went — including when that
-- membership had only been tombstoned (deleted_at set). Deleting the
-- restaurant cascaded its restaurant_groups rows away, tombstone and all, and
-- the pull is driven by exactly those rows: the other members were never told,
-- and kept the restaurant on their devices for good.
--
-- Now only a hard delete of a membership prunes — a group dissolving, or an
-- account being erased — so the restaurant still goes when nothing could ever
-- point at it again. A tombstoned membership is left in place for every member
-- to pull, and the restaurant it named stays as it is: a tombstone itself when
-- it was deleted, or its author's own row when they took it back out of every
-- group (readable by them alone, through restaurants_select_visible), ready to
-- be shared again with its id intact.

drop trigger if exists restaurant_groups_prune_orphans
  on public.restaurant_groups;

create trigger restaurant_groups_prune_orphans
  after delete on public.restaurant_groups
  for each row execute function private.prune_orphan_restaurant();
