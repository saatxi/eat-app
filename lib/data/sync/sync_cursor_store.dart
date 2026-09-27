import '../db/app_database.dart';

/// This device's pull cursors, one per group.
///
/// A cursor is the newest remote `updated_at` this device has already applied
/// to its local database. The next pull asks the remote for rows strictly
/// newer than the stored value, so each device advances its own cursor and no
/// two devices' clocks ever have to agree.
class SyncCursorStore {
  SyncCursorStore(this._database);

  final AppDatabase _database;

  /// The cursor for [groupId], or null when nothing has been pulled yet.
  Future<String?> read(String groupId) async {
    final SyncCursor? row = await (_database
            .select(_database.syncCursors)
          ..where((t) => t.groupId.equals(groupId)))
        .getSingleOrNull();
    return row?.lastPulledAt;
  }

  /// Stores the newest `updated_at` applied for [groupId], replacing whatever
  /// was there before.
  Future<void> advance(String groupId, String lastPulledAt) =>
      _database.into(_database.syncCursors).insertOnConflictUpdate(
        SyncCursorsCompanion.insert(
          groupId: groupId,
          lastPulledAt: lastPulledAt,
        ),
      );
}
