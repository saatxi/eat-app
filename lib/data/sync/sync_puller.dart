import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;

import '../db/app_database.dart';
import 'photo_blob_sync.dart';
import 'remote_models.dart';
import 'sync_cursor_store.dart';
import 'sync_mapper.dart';
import 'sync_transport.dart';

/// Pulls a group's remote changes in and applies them to drift.
///
/// Writes straight to the database — outside the repository — so a pulled
/// row is applied without being re-enqueued as a local change.
class SyncPuller {
  SyncPuller(this._database, this._cursors, this._transport, this._photoBlobs);

  final AppDatabase _database;
  final SyncCursorStore _cursors;
  final SyncTransport _transport;
  final PhotoBlobSync _photoBlobs;

  /// Applies everything in [groupId] that is newer than this device's
  /// cursor, then advances the cursor to the newest `updated_at` seen.
  ///
  /// The cursor alone cannot vouch that the device holds the whole group —
  /// a membership skipped or lost behind it is never newer than it again —
  /// so every pull also checks the group's live memberships against the
  /// local rows, and fetches whatever is missing whole, regardless of its
  /// age.
  Future<void> pullGroup(String groupId) async {
    final String? since = await _cursors.read(groupId);
    final GroupPull pull = await _transport.pullGroup(
      groupId: groupId,
      since: since,
    );
    await _apply(groupId, pull);

    final String? cursor = pull.cursor;
    if (cursor != null) {
      await _cursors.advance(groupId, cursor);
    }

    final List<String> missing = await _missingRestaurantIds(
      groupId,
      pull.liveRestaurantIds,
    );
    if (missing.isNotEmpty) {
      await _apply(
        groupId,
        await _transport.pullGroup(groupId: groupId, restaurantIds: missing),
      );
    }
  }

  /// Writes [pull] into drift in one transaction, downloading its photo
  /// binaries first.
  Future<void> _apply(String groupId, GroupPull pull) async {
    // Download every binary *before* opening the transaction: a network call
    // inside it would hold the database open for its whole duration. A
    // tombstone has no binary, and with no blob store configured the photos
    // are applied as rows with no local file.
    final Map<String, String> localPaths = await _photoBlobs.downloadAll(
      pull.photos,
    );

    final List<Photo> purgedPhotos = <Photo>[];
    await _database.transaction(() async {
      // Restaurants first: a membership, a visit and a photo all reference
      // their restaurant, and the foreign keys are enforced. A restaurant
      // new to this device adopts the group it arrived through as its home
      // group; one already here keeps its own — including none, for a
      // restaurant its author has just taken back out of every group.
      for (final RemoteRestaurant r in pull.restaurants) {
        final Restaurant? existing = await _restaurantById(r.id);
        await _database.into(_database.restaurants).insertOnConflictUpdate(
          toRestaurant(
            r,
            homeGroupId: existing == null ? groupId : existing.groupId,
          ).toCompanion(false),
        );
      }
      // A membership whose restaurant this device does not have is
      // skipped: it is the tombstone of one removed before this device
      // ever saw it, whose row the server no longer shows this member.
      final Set<String> membershipRestaurantIds = <String>{};
      for (final RemoteRestaurantGroup rg in pull.restaurantGroups) {
        if (await _restaurantById(rg.restaurantId) == null) {
          continue;
        }
        await _database.into(_database.restaurantGroups).insertOnConflictUpdate(
          toRestaurantGroup(rg).toCompanion(false),
        );
        membershipRestaurantIds.add(rg.restaurantId);
      }
      for (final RemoteVisit v in pull.visits) {
        await _database.into(_database.visits).insertOnConflictUpdate(
          toVisit(v).toCompanion(false),
        );
      }
      for (final RemotePhoto p in pull.photos) {
        await _database.into(_database.photos).insertOnConflictUpdate(
          toPhoto(p, localPath: localPaths[p.id] ?? '').toCompanion(false),
        );
      }
      purgedPhotos.addAll(await _settleMemberships(membershipRestaurantIds));
    });
    await _photoBlobs.deleteFiles(purgedPhotos);
  }

  /// The ids among [liveRestaurantIds] that this device lacks: no
  /// restaurant row, or no membership row in [groupId] at all.
  ///
  /// A membership this device holds in *any* state counts as present — a
  /// local tombstone is a removal still waiting to be pushed, and fetching
  /// the live remote row would undo it.
  Future<List<String>> _missingRestaurantIds(
    String groupId,
    List<String> liveRestaurantIds,
  ) async {
    if (liveRestaurantIds.isEmpty) {
      return const <String>[];
    }
    final List<RestaurantGroup> held = await (_database
            .select(_database.restaurantGroups)
          ..where(
            (t) =>
                t.groupId.equals(groupId) &
                t.restaurantId.isIn(liveRestaurantIds),
          ))
        .get();
    final List<Restaurant> restaurants = await (_database
            .select(_database.restaurants)
          ..where((t) => t.id.isIn(liveRestaurantIds)))
        .get();
    final Set<String> present = <String>{
      for (final RestaurantGroup rg in held) rg.restaurantId,
    }.intersection(<String>{for (final Restaurant r in restaurants) r.id});
    return <String>[
      for (final String id in liveRestaurantIds)
        if (!present.contains(id)) id,
    ];
  }

  Future<Restaurant?> _restaurantById(String id) => (_database
          .select(_database.restaurants)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();

  /// Brings each of [restaurantIds] — the restaurants a pull just changed a
  /// membership of — in line with the memberships it has left.
  ///
  /// One still in some group keeps one of them as its home group. One left
  /// in none is gone from this device: it was deleted, or taken out of
  /// every group this member can see, and either way there is no group left
  /// to show it in — without this it would surface in the personal list
  /// instead. The exception is a restaurant with no home group, which only
  /// its author's device has: the author took it back out of every group,
  /// and it is theirs again.
  ///
  /// Returns the purged photo rows, so their files can be removed once the
  /// transaction has committed.
  Future<List<Photo>> _settleMemberships(Set<String> restaurantIds) async {
    final List<Photo> purged = <Photo>[];
    for (final String restaurantId in restaurantIds) {
      final Restaurant? restaurant = await _restaurantById(restaurantId);
      if (restaurant == null || restaurant.groupId == null) {
        continue;
      }
      final List<RestaurantGroup> live = await (_database
              .select(_database.restaurantGroups)
            ..where(
              (t) => t.restaurantId.equals(restaurantId) & t.deletedAt.isNull(),
            ))
          .get();
      if (live.isEmpty) {
        purged.addAll(await _purgeRestaurant(restaurantId));
      } else if (!live.any((rg) => rg.groupId == restaurant.groupId)) {
        await (_database.update(_database.restaurants)
              ..where((t) => t.id.equals(restaurantId)))
            .write(
              RestaurantsCompanion(groupId: Value<String?>(live.first.groupId)),
            );
      }
    }
    return purged;
  }

  /// Deletes [restaurantId] from this device outright — the restaurant, and
  /// by cascade its visits, photos and memberships — along with any of
  /// their queue entries, returning its photo rows so their files can go
  /// too.
  Future<List<Photo>> _purgeRestaurant(String restaurantId) async {
    final List<Visit> visits = await (_database.select(_database.visits)
          ..where((t) => t.restaurantId.equals(restaurantId)))
        .get();
    final List<String> visitIds = <String>[for (final Visit v in visits) v.id];
    final List<Photo> photos = await (_database.select(_database.photos)
          ..where(
            (t) => t.restaurantId.equals(restaurantId) | t.visitId.isIn(visitIds),
          ))
        .get();
    await (_database.delete(_database.pendingSyncs)
          ..where(
            (t) => t.rowId.isIn(<String>[
              restaurantId,
              ...visitIds,
              for (final Photo p in photos) p.id,
            ]),
          ))
        .go();
    await (_database.delete(_database.restaurants)
          ..where((t) => t.id.equals(restaurantId)))
        .go();
    return photos;
  }
}
