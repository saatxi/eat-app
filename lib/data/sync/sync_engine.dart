import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
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
/// local change. Pushing is ordered restaurants → live memberships → visits →
/// photos → removed memberships: a membership references its restaurant, and
/// the server only lets a visit or photo be written while its restaurant has a
/// live membership the writer may edit — so a membership's tombstone goes last.
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
    // group's membership rows are pushed (the group is the push's scope), and
    // only the live ones for now — the removed ones go last, below.
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
        await _pushPhotoBinaries(rows, remotes);
        await _transport.pushPhotos(remotes);
      }
    }

    // Removed memberships last. The server decides who may write a visit or a
    // photo from the restaurant's *live* memberships, so tombstoning the last
    // one first would leave the tombstones of the restaurant's own visits and
    // photos queued above refused on every retry.
    if (removedMemberships.isNotEmpty) {
      await _transport.pushRestaurantGroups(
        removedMemberships.map(toRemoteRestaurantGroup).toList(),
      );
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

    final List<Photo> purgedPhotos = <Photo>[];
    await _database.transaction(() async {
      // Restaurants first: a membership, a visit and a photo all reference
      // their restaurant, and the foreign keys are enforced. A restaurant new
      // to this device adopts the group it arrived through as its home group;
      // one already here keeps its own — including none, for a restaurant its
      // author has just taken back out of every group.
      for (final RemoteRestaurant r in pull.restaurants) {
        final Restaurant? existing = await _restaurantById(r.id);
        await _database.into(_database.restaurants).insertOnConflictUpdate(
          toRestaurant(
            r,
            homeGroupId: existing == null ? groupId : existing.groupId,
          ).toCompanion(false),
        );
      }
      // A membership whose restaurant this device does not have is skipped:
      // it is the tombstone of one removed before this device ever saw it,
      // whose row the server no longer shows this member.
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
    await _deletePhotoFiles(purgedPhotos);

    final String? cursor = pull.cursor;
    if (cursor != null) {
      await _cursors.advance(groupId, cursor);
    }
  }

  Future<Restaurant?> _restaurantById(String id) => (_database
          .select(_database.restaurants)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();

  /// Brings each of [restaurantIds] — the restaurants a pull just changed a
  /// membership of — in line with the memberships it has left.
  ///
  /// One still in some group keeps one of them as its home group. One left in
  /// none is gone from this device: it was deleted, or taken out of every group
  /// this member can see, and either way there is no group left to show it in —
  /// without this it would surface in the personal list instead. The exception
  /// is a restaurant with no home group, which only its author's device has:
  /// the author took it back out of every group, and it is theirs again.
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

  /// Deletes [restaurantId] from this device outright — the restaurant, and by
  /// cascade its visits, photos and memberships — along with any of their
  /// queue entries, returning its photo rows so their files can go too.
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

  /// Removes the local files behind [photos], skipping any that never had one
  /// (a photo whose binary could not be downloaded).
  Future<void> _deletePhotoFiles(List<Photo> photos) async {
    final PhotoStorage? storage = photoStorage;
    if (storage == null) {
      return;
    }
    for (final Photo photo in photos) {
      if (photo.path.isNotEmpty) {
        await storage.delete(photo.path);
      }
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
