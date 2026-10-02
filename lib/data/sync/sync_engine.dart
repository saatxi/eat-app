import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../photo/photo_storage.dart';
import 'pending_sync_store.dart';
import 'photo_blob_store.dart';
import 'remote_models.dart';
import 'sync_cursor_store.dart';
import 'sync_mapper.dart';
import 'sync_table.dart';
import 'sync_transport.dart';

/// Orchestrates the two halves of the sync layer: pushing the pending queue
/// out, and pulling remote changes in.
///
/// A screen or a scheduler drives [syncGroup]; the [SyncTransport] is the only
/// piece that knows the remote exists. Pulls write straight to drift — outside
/// the repository — so a pulled row is applied without being re-enqueued as a
/// local change. Pushing is ordered restaurants → memberships → visits →
/// photos, because a membership references its restaurant and a visit or photo
/// references its restaurant too.
class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required PendingSyncStore pending,
    required SyncCursorStore cursors,
    required SyncTransport transport,
    this.photoStorage,
    this.blobs,
  // Private named fields cannot take initializing formals (Dart has no
  // private named parameters), so the assignments stay explicit.
  // ignore: prefer_initializing_formals
  }) : _database = database,
       // ignore: prefer_initializing_formals
       _pending = pending,
       // ignore: prefer_initializing_formals
       _cursors = cursors,
       // ignore: prefer_initializing_formals
       _transport = transport;

  final AppDatabase _database;
  final PendingSyncStore _pending;
  final SyncCursorStore _cursors;
  final SyncTransport _transport;

  /// The local photo store and the remote blob store, both needed together for
  /// photos to sync at all. Null (a unit test, a build with no backend) simply
  /// skips photo binaries — rows still sync.
  final PhotoStorage? photoStorage;
  final PhotoBlobStore? blobs;

  /// Pushes this device's changes, then pulls the group's — push first so the
  /// remote has our rows before we ask what changed since we last looked.
  ///
  /// A push that fails does not cost us the pull: what the rest of the group
  /// changed is independent of whether our own queue could be sent, and a row
  /// the server keeps refusing would otherwise freeze every future pull behind
  /// it — the very rows we came for would never arrive. The push failure is
  /// remembered and rethrown once the pull has had its chance, so the caller
  /// still learns about it.
  Future<void> syncGroup(String groupId) async {
    Object? pushError;
    StackTrace? pushStack;
    try {
      await pushGroup(groupId);
    } catch (error, stackTrace) {
      pushError = error;
      pushStack = stackTrace;
    }

    await pullGroup(groupId);

    if (pushError != null) {
      Error.throwWithStackTrace(pushError, pushStack!);
    }
  }

  /// Sends every pending row in [groupId] to the remote, in dependency order,
  /// and drops each table's queue entries only once its push has succeeded.
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
    // group's membership rows are pushed (the group is the push's scope).
    if (membershipRestaurantIds.isNotEmpty) {
      final List<RestaurantGroup> rows = await (_database
              .select(_database.restaurantGroups)
            ..where(
              (t) =>
                  t.restaurantId.isIn(membershipRestaurantIds) &
                  t.groupId.equals(groupId),
            ))
          .get();
      if (rows.isNotEmpty) {
        await _transport.pushRestaurantGroups(
          rows.map(toRemoteRestaurantGroup).toList(),
        );
      }
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
        await _pushPhotoBinaries(rows, remotes);
        await _transport.pushPhotos(remotes);
      }
    }

    // Drop the queue entries only now that every table's push has succeeded,
    // so a mid-way failure leaves the whole group to retry.
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

  /// Uploads each live photo's binary before its row is upserted, so a row never
  /// points at an object that isn't there. A tombstone has no binary to send,
  /// and with no blob store configured (a unit test) the whole step is skipped.
  Future<void> _pushPhotoBinaries(
    List<Photo> rows,
    List<RemotePhoto> remotes,
  ) async {
    final PhotoBlobStore? blobs = this.blobs;
    final PhotoStorage? storage = photoStorage;
    if (blobs == null || storage == null) {
      return;
    }
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].deletedAt != null) {
        continue;
      }
      await blobs.upload(
        remotes[i].storagePath,
        await storage.readBytes(rows[i].path),
      );
    }
  }

  /// Applies everything in [groupId] that is newer than this device's cursor,
  /// then advances the cursor to the newest `updated_at` seen.
  Future<void> pullGroup(String groupId) async {
    final String? since = await _cursors.read(groupId);
    final GroupPull pull = await _transport.pullGroup(
      groupId: groupId,
      since: since,
    );

    // Download every binary *before* opening the transaction: a network call
    // inside it would hold the database open for its whole duration. A
    // tombstone has no binary, and with no blob store configured the photos are
    // applied as rows with no local file.
    final Map<String, String> localPaths = await _downloadPhotoBinaries(
      pull.photos,
    );

    await _database.transaction(() async {
      // Memberships first: a restaurant new to this device adopts the group it
      // arrived through as its home group.
      for (final RemoteRestaurantGroup rg in pull.restaurantGroups) {
        await _database.into(_database.restaurantGroups).insertOnConflictUpdate(
          toRestaurantGroup(rg).toCompanion(false),
        );
      }
      for (final RemoteRestaurant r in pull.restaurants) {
        final Restaurant? existing = await (_database
                .select(_database.restaurants)
              ..where((t) => t.id.equals(r.id)))
            .getSingleOrNull();
        await _database.into(_database.restaurants).insertOnConflictUpdate(
          toRestaurant(r, homeGroupId: existing?.groupId ?? groupId)
              .toCompanion(false),
        );
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
    });

    final String? cursor = pull.cursor;
    if (cursor != null) {
      await _cursors.advance(groupId, cursor);
    }
  }

  /// Downloads each live remote photo into the local store, returning the path
  /// it landed at, keyed by photo id. Tombstones get no entry.
  ///
  /// A single unreachable or forbidden binary is logged and skipped rather than
  /// aborting the pull: it is the *other* members who download the photos, so
  /// failing the whole batch here would silently starve exactly the device that
  /// did not create the photo — no rows at all, for a photo that is secondary
  /// to them. The row is still applied (without a local file this time).
  Future<Map<String, String>> _downloadPhotoBinaries(
    List<RemotePhoto> photos,
  ) async {
    final PhotoBlobStore? blobs = this.blobs;
    final PhotoStorage? storage = photoStorage;
    if (blobs == null || storage == null) {
      return const <String, String>{};
    }
    final Map<String, String> paths = <String, String>{};
    for (final RemotePhoto photo in photos) {
      if (photo.deletedAt != null) {
        continue;
      }
      try {
        paths[photo.id] = await storage.writeBytes(
          await blobs.download(photo.storagePath),
        );
      } catch (error, stackTrace) {
        debugPrint('Downloading photo ${photo.id} failed: $error');
        if (kDebugMode) {
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }
    return paths;
  }
}
