import 'package:drift/drift.dart' show BooleanExpressionOperators;

import '../db/app_database.dart';
import 'pending_sync_store.dart';
import 'photo_blob_sync.dart';
import 'remote_models.dart';
import 'sync_mapper.dart';
import 'sync_table.dart';
import 'sync_transport.dart';

/// Sends a group's pending queue to the remote, in dependency order.
///
/// Pushing is ordered restaurants → live memberships → visits → photos →
/// removed memberships: a membership references its restaurant, and the
/// server only lets a visit or photo be written while its restaurant has a
/// live membership the writer may edit — so a membership's tombstone goes
/// last.
class SyncPusher {
  SyncPusher(
    this._database,
    this._pending,
    this._transport,
    this._photoBlobs,
  );

  final AppDatabase _database;
  final PendingSyncStore _pending;
  final SyncTransport _transport;
  final PhotoBlobSync _photoBlobs;

  /// Sends every pending row in [groupId] to the remote, in dependency
  /// order, and drops each table's queue entries only once its push has
  /// succeeded.
  ///
  /// A restaurant row is pushed whenever it is dirty *or* one of its
  /// memberships is, so the membership's foreign key always resolves.
  Future<void> pushGroup(String groupId) async {
    final List<PendingSync> entries = await _pending.pendingForGroup(groupId);
    if (entries.isEmpty) {
      return;
    }

    final Set<String> dirtyRestaurantIds = <String>{};
    final List<String> membershipRestaurantIds = <String>[];
    final List<String> visitIds = <String>[];
    final List<String> photoIds = <String>[];
    for (final PendingSync e in entries) {
      if (e.sharedTable == SyncTable.restaurants.name) {
        dirtyRestaurantIds.add(e.rowId);
      } else if (e.sharedTable == SyncTable.restaurantGroups.name) {
        membershipRestaurantIds.add(e.rowId);
        dirtyRestaurantIds.add(e.rowId);
      } else if (e.sharedTable == SyncTable.visits.name) {
        visitIds.add(e.rowId);
      } else if (e.sharedTable == SyncTable.photos.name) {
        photoIds.add(e.rowId);
      }
    }

    // Restaurants first: both the ones changed directly and the ones a
    // membership references.
    final List<String> restaurantIds = dirtyRestaurantIds.toList();
    if (restaurantIds.isNotEmpty) {
      final List<Restaurant> rows = await (_database
              .select(_database.restaurants)
            ..where((t) => t.id.isIn(restaurantIds)))
          .get();
      if (rows.isNotEmpty) {
        await _transport.pushRestaurants(
          rows.map(toRemoteRestaurant).toList(),
        );
      }
    }

    // Memberships, now that their restaurants exist remotely. Only this
    // group's membership rows are pushed (the group is the push's scope),
    // and only the live ones for now — the removed ones go last, below.
    final List<RestaurantGroup> memberships = membershipRestaurantIds.isEmpty
        ? const <RestaurantGroup>[]
        : await (_database
                .select(_database.restaurantGroups)
              ..where(
                (t) =>
                    t.restaurantId.isIn(membershipRestaurantIds) &
                    t.groupId.equals(groupId),
              ))
            .get();
    final List<RestaurantGroup> liveMemberships = <RestaurantGroup>[
      for (final RestaurantGroup rg in memberships)
        if (rg.deletedAt == null) rg,
    ];
    final List<RestaurantGroup> removedMemberships = <RestaurantGroup>[
      for (final RestaurantGroup rg in memberships)
        if (rg.deletedAt != null) rg,
    ];
    if (liveMemberships.isNotEmpty) {
      await _transport.pushRestaurantGroups(
        liveMemberships.map(toRemoteRestaurantGroup).toList(),
      );
    }

    if (visitIds.isNotEmpty) {
      final List<Visit> rows = await (_database
              .select(_database.visits)
            ..where((t) => t.id.isIn(visitIds)))
          .get();
      if (rows.isNotEmpty) {
        await _transport.pushVisits(rows.map(toRemoteVisit).toList());
      }
    }

    if (photoIds.isNotEmpty) {
      final List<Photo> rows = await (_database
              .select(_database.photos)
            ..where((t) => t.id.isIn(photoIds)))
          .get();
      if (rows.isNotEmpty) {
        final List<RemotePhoto> remotes = <RemotePhoto>[
          for (final Photo row in rows) toRemotePhoto(row),
        ];
        await _photoBlobs.uploadMissing(rows, remotes);
        await _transport.pushPhotos(remotes);
      }
    }

    // Removed memberships last. The server decides who may write a visit or
    // a photo from the restaurant's *live* memberships, so tombstoning the
    // last one first would leave the tombstones of the restaurant's own
    // visits and photos queued above refused on every retry.
    if (removedMemberships.isNotEmpty) {
      await _transport.pushRestaurantGroups(
        removedMemberships.map(toRemoteRestaurantGroup).toList(),
      );
    }

    // Drop the queue entries only now that every table's push has
    // succeeded, so a mid-way failure leaves the whole group to retry.
    await _pending.complete(
      SyncTable.restaurants,
      entries
          .where((PendingSync e) => e.sharedTable == SyncTable.restaurants.name)
          .map((PendingSync e) => e.rowId),
    );
    await _pending.complete(SyncTable.restaurantGroups, membershipRestaurantIds);
    await _pending.complete(SyncTable.visits, visitIds);
    await _pending.complete(SyncTable.photos, photoIds);
  }
}
