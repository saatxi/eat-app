import '../db/app_database.dart';
import 'pending_sync_store.dart';
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
/// local change. Pushing is ordered restaurants-before-visits (the queue
/// already returns them that way), because a visit references its restaurant.
class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required PendingSyncStore pending,
    required SyncCursorStore cursors,
    required SyncTransport transport,
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

  /// Pushes this device's changes, then pulls the group's — push first so the
  /// remote has our rows before we ask what changed since we last looked.
  Future<void> syncGroup(String groupId) async {
    await pushGroup(groupId);
    await pullGroup(groupId);
  }

  /// Sends every pending row in [groupId] to the remote, in dependency order,
  /// and drops each table's queue entries only once its push has succeeded.
  Future<void> pushGroup(String groupId) async {
    final List<PendingSync> entries = await _pending.pendingForGroup(groupId);
    if (entries.isEmpty) {
      return;
    }

    final List<String> restaurantIds = <String>[
      for (final PendingSync e in entries)
        if (e.sharedTable == SyncTable.restaurants.name) e.rowId,
    ];
    final List<String> visitIds = <String>[
      for (final PendingSync e in entries)
        if (e.sharedTable == SyncTable.visits.name) e.rowId,
    ];

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
      await _pending.complete(SyncTable.restaurants, restaurantIds);
    }

    if (visitIds.isNotEmpty) {
      final List<Visit> rows = await (_database
              .select(_database.visits)
            ..where((t) => t.id.isIn(visitIds)))
          .get();
      if (rows.isNotEmpty) {
        await _transport.pushVisits(rows.map(toRemoteVisit).toList());
      }
      await _pending.complete(SyncTable.visits, visitIds);
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

    await _database.transaction(() async {
      for (final RemoteRestaurant r in pull.restaurants) {
        await _database.into(_database.restaurants).insertOnConflictUpdate(
          toRestaurant(r).toCompanion(false),
        );
      }
      for (final RemoteVisit v in pull.visits) {
        await _database.into(_database.visits).insertOnConflictUpdate(
          toVisit(v).toCompanion(false),
        );
      }
    });

    final String? cursor = pull.cursor;
    if (cursor != null) {
      await _cursors.advance(groupId, cursor);
    }
  }
}
