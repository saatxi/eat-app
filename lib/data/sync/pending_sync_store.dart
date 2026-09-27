import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'sync_table.dart';

/// The local queue of shared rows still waiting to be pushed to the remote,
/// and nothing else.
///
/// This is a set keyed by (table, row), not a log: writing the same row twice
/// coalesces into one entry, and the entry's `groupId` is the row's group at
/// enqueue time. A push reads each entry's current row from its own table, so
/// it always sends the latest shape — including a tombstone whose `deletedAt`
/// was set after the entry was enqueued.
class PendingSyncStore {
  PendingSyncStore(this._database);

  final AppDatabase _database;

  /// Marks one shared row as dirty in [groupId].
  Future<void> enqueue(SyncTable table, String rowId, String groupId) =>
      enqueueAll(<PendingSync>[
        PendingSync(sharedTable: table.name, rowId: rowId, groupId: groupId),
      ]);

  /// Marks several rows at once, atomically. An empty iterable is a no-op.
  Future<void> enqueueAll(Iterable<PendingSync> entries) {
    final List<PendingSync> list = entries.toList();
    if (list.isEmpty) {
      return Future<void>.value();
    }
    return _database.transaction(() async {
      for (final PendingSync entry in list) {
        await _database.into(_database.pendingSyncs).insertOnConflictUpdate(
          PendingSyncsCompanion.insert(
            sharedTable: entry.sharedTable,
            rowId: entry.rowId,
            groupId: entry.groupId,
          ),
        );
      }
    });
  }

  /// Every entry still pending for [groupId], ordered so restaurants come
  /// before visits, which come before photos — the order a push must follow.
  Future<List<PendingSync>> pendingForGroup(String groupId) async {
    final List<PendingSync> rows = await (_database
            .select(_database.pendingSyncs)
          ..where((t) => t.groupId.equals(groupId)))
        .get();
    final Map<String, int> order = <String, int>{
      for (final (int index, SyncTable table) in SyncTable.values.indexed)
        table.name: index,
    };
    rows.sort(
      (PendingSync a, PendingSync b) =>
          order[a.sharedTable]!.compareTo(order[b.sharedTable]!),
    );
    return rows;
  }

  /// Removes the entries for [table]/[rowIds] after a successful push. An
  /// empty [rowIds] is a no-op.
  Future<void> complete(SyncTable table, Iterable<String> rowIds) async {
    final List<String> ids = rowIds.toList();
    if (ids.isEmpty) {
      return;
    }
    await (_database.delete(_database.pendingSyncs)
          ..where(
            (t) => t.sharedTable.equals(table.name) & t.rowId.isIn(ids),
          ))
        .go();
  }
}
