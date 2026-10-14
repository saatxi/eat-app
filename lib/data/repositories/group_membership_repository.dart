import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;

import '../db/app_database.dart';
import '../db/daos/restaurant_dao.dart';
import '../share/restaurant_share_models.dart';
import '../sync/sync_table.dart';
import 'write_effects.dart';

/// Which groups a restaurant belongs to, and the bulk "share into a group"
/// flows that write that membership.
///
/// A restaurant's membership is a many-to-many `restaurant_groups` junction,
/// so one canonical restaurant can be shared into several groups at once; its
/// own `groupId` column just names its *home* group, used for its visits' and
/// photos' Storage folder.
class GroupMembershipRepository {
  GroupMembershipRepository(this._database, this._effects);

  final AppDatabase _database;
  final WriteEffects _effects;

  late final RestaurantDao _restaurants = _database.restaurantDao;

  /// The groups [restaurantId] currently belongs to (live memberships only).
  Future<List<String>> groupIdsForRestaurant(String restaurantId) async {
    final List<RestaurantGroup> rows = await (_database
            .select(_database.restaurantGroups)
          ..where(
            (t) => t.restaurantId.equals(restaurantId) & t.deletedAt.isNull(),
          ))
        .get();
    return <String>[for (final RestaurantGroup rg in rows) rg.groupId];
  }

  /// Replaces [restaurantId]'s group memberships with [groupIds], attributed
  /// to [createdBy]. A group that is added writes or revives a membership;
  /// one that is dropped is tombstoned (and queued). Empty [groupIds] leaves
  /// the restaurant private: it keeps no membership and is not synced
  /// anywhere.
  Future<void> setRestaurantGroups({
    required String restaurantId,
    required Set<String> groupIds,
    required String createdBy,
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<RestaurantGroup> existing = await (_database
            .select(_database.restaurantGroups)
          ..where((t) => t.restaurantId.equals(restaurantId)))
        .get();
    final Map<String, RestaurantGroup> byGroup = <String, RestaurantGroup>{
      for (final RestaurantGroup rg in existing) rg.groupId: rg,
    };

    await _database.transaction(() async {
      // Drop the memberships the user removed, tombstoned so it propagates.
      for (final RestaurantGroup rg in existing) {
        if (groupIds.contains(rg.groupId) || rg.deletedAt != null) {
          continue;
        }
        await (_database.update(_database.restaurantGroups)
              ..where(
                (t) =>
                    t.restaurantId.equals(restaurantId) &
                    t.groupId.equals(rg.groupId),
              ))
            .write(
              RestaurantGroupsCompanion(
                deletedAt: Value<int>(now),
                updatedAt: Value<int>(now),
              ),
            );
        await _effects.pending.enqueue(
          SyncTable.restaurantGroups,
          restaurantId,
          rg.groupId,
        );
      }

      // Add (or revive) the memberships the user kept.
      await _upsertMemberships(
        restaurantId: restaurantId,
        groupIds: groupIds,
        byGroup: byGroup,
        createdBy: createdBy,
        now: now,
      );
    });

    await _applyHomeGroup(restaurantId);
    await _effects.afterWrite();
  }

  /// Adds every one of [restaurantIds] to every one of [groupIds], attributed
  /// to [createdBy] — the Journal's bulk "Add to group" action.
  ///
  /// Add-only: a membership the restaurant already has is kept (and keeps
  /// its original author), and none is ever removed. A personal restaurant
  /// gains its first group as its home, exactly as the edit form's save
  /// would give it, so its visits and photos have a Storage folder to sync
  /// into.
  Future<void> addRestaurantsToGroups({
    required Set<String> restaurantIds,
    required Set<String> groupIds,
    required String createdBy,
  }) async {
    if (restaurantIds.isEmpty || groupIds.isEmpty) {
      return;
    }
    final int now = DateTime.now().millisecondsSinceEpoch;

    await _database.transaction(() async {
      for (final String restaurantId in restaurantIds) {
        final Restaurant? row = await _restaurants.getById(restaurantId);
        if (row == null || row.deletedAt != null) {
          continue;
        }
        if (row.groupId == null) {
          final String home = groupIds.first;
          await _restaurants.updateRestaurant(
            row.copyWith(
              groupId: Value<String?>(home),
              createdBy: Value<String?>(row.createdBy ?? createdBy),
              updatedAt: now,
            ),
          );
          await _effects.pending.enqueue(
            SyncTable.restaurants,
            restaurantId,
            home,
          );
        }

        final List<RestaurantGroup> existing = await (_database
                .select(_database.restaurantGroups)
              ..where((t) => t.restaurantId.equals(restaurantId)))
            .get();
        await _upsertMemberships(
          restaurantId: restaurantId,
          groupIds: groupIds,
          byGroup: <String, RestaurantGroup>{
            for (final RestaurantGroup rg in existing) rg.groupId: rg,
          },
          createdBy: createdBy,
          now: now,
        );
      }
    });

    await _effects.afterWrite();
    for (final String groupId in groupIds) {
      _effects.notifySharedWrite(groupId);
    }
  }

  /// Which of [candidates] look like a restaurant one of [groupIds] already
  /// has — the same name, and the same address unless either has none (see
  /// [isLikelyDuplicateOf]) — so the caller can warn before sharing a second
  /// copy in. Every copy gets its own id, so nothing downstream would merge
  /// it.
  ///
  /// A group the candidate is itself already in is not asked about: adding
  /// it there again changes nothing.
  Future<List<Restaurant>> likelyGroupDuplicates({
    required Iterable<Restaurant> candidates,
    required Set<String> groupIds,
  }) async {
    if (groupIds.isEmpty) {
      return const <Restaurant>[];
    }
    final List<RestaurantGroup> memberships = await (_database.select(
      _database.restaurantGroups,
    )..where((t) => t.groupId.isIn(groupIds) & t.deletedAt.isNull())).get();
    if (memberships.isEmpty) {
      return const <Restaurant>[];
    }
    final Map<String, Restaurant> members = <String, Restaurant>{
      for (final Restaurant row
          in await (_database.select(_database.restaurants)..where(
                (t) =>
                    t.id.isIn(
                      memberships.map((RestaurantGroup rg) => rg.restaurantId),
                    ) &
                    t.deletedAt.isNull(),
              ))
              .get())
        row.id: row,
    };
    final Map<String, List<Restaurant>> byGroup = <String, List<Restaurant>>{};
    for (final RestaurantGroup rg in memberships) {
      final Restaurant? member = members[rg.restaurantId];
      if (member != null) {
        (byGroup[rg.groupId] ??= <Restaurant>[]).add(member);
      }
    }
    return <Restaurant>[
      for (final Restaurant candidate in candidates)
        if (byGroup.values.any((List<Restaurant> group) {
          if (group.any((Restaurant m) => m.id == candidate.id)) {
            return false;
          }
          return group.any((Restaurant m) => isLikelyDuplicateOf(candidate, m));
        }))
          candidate,
    ];
  }

  /// [likelyGroupDuplicates] for restaurants already on this device, by id —
  /// the Journal's bulk "Add to group" selection.
  Future<List<Restaurant>> likelyGroupDuplicatesOf({
    required Set<String> restaurantIds,
    required Set<String> groupIds,
  }) async {
    final List<Restaurant> rows = <Restaurant>[
      for (final String id in restaurantIds) ?await _restaurants.getById(id),
    ];
    return likelyGroupDuplicates(candidates: rows, groupIds: groupIds);
  }

  /// Records (or refreshes) [restaurant]'s membership in its home group and
  /// queues it, so the junction — which is what actually shares the
  /// restaurant — travels with the row. A private restaurant has no group
  /// and is skipped. Called by [RestaurantRepository.insert] and
  /// [RestaurantRepository.update].
  Future<void> recordMembership(Restaurant restaurant) async {
    final String? groupId = restaurant.groupId;
    final String? createdBy = restaurant.createdBy;
    if (groupId == null || createdBy == null) {
      return;
    }
    await _database.into(_database.restaurantGroups).insertOnConflictUpdate(
      RestaurantGroupsCompanion.insert(
        restaurantId: restaurant.id,
        groupId: groupId,
        createdBy: createdBy,
        updatedAt: Value<int>(restaurant.updatedAt),
      ),
    );
    await _effects.pending.enqueue(
      SyncTable.restaurantGroups,
      restaurant.id,
      groupId,
    );
  }

  /// Writes or revives [restaurantId]'s membership in each of [groupIds] and
  /// queues it. A membership that already existed ([byGroup]) keeps its
  /// original author; a new one is attributed to [createdBy].
  Future<void> _upsertMemberships({
    required String restaurantId,
    required Set<String> groupIds,
    required Map<String, RestaurantGroup> byGroup,
    required String createdBy,
    required int now,
  }) async {
    for (final String groupId in groupIds) {
      final RestaurantGroup? prior = byGroup[groupId];
      await _database.into(_database.restaurantGroups).insertOnConflictUpdate(
        RestaurantGroupsCompanion.insert(
          restaurantId: restaurantId,
          groupId: groupId,
          createdBy: prior?.createdBy ?? createdBy,
          updatedAt: Value<int>(now),
          deletedAt: const Value<int?>(null),
        ),
      );
      await _effects.pending.enqueue(
        SyncTable.restaurantGroups,
        restaurantId,
        groupId,
      );
    }
  }

  /// Points the restaurant's home group (its `groupId` column) at one of its
  /// live memberships, or null when it has none, so its visits and photos
  /// keep a Storage home without the row itself being group-scoped.
  Future<void> _applyHomeGroup(String restaurantId) async {
    final List<String> groups = await groupIdsForRestaurant(restaurantId);
    final String? home = groups.isEmpty ? null : groups.first;
    final Restaurant? row = await _restaurants.getById(restaurantId);
    if (row == null || row.groupId == home) {
      return;
    }
    await _restaurants.updateRestaurant(
      row.copyWith(groupId: Value<String?>(home)),
    );
  }
}
