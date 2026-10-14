import '../db/app_database.dart';
import '../photo/photo_storage.dart';
import '../share/backup_writer.dart';
import '../share/restaurant_share_models.dart';
import '../sync/pending_sync_store.dart';
import '../sync/sync_table.dart';

/// What every writer in the split repository does after a row lands: queue it
/// for sync, snapshot the backup, tell the home-screen widget, and clean up
/// photo files. Collected here once rather than copied into each of
/// [VisitRepository], [PhotoRepository] and the rest, since all of them need
/// exactly the same four things done to exactly the same collaborators.
class WriteEffects {
  WriteEffects(
    this._database, {
    required this.exportAll,
    this.backupWriter,
    this.photoStorage,
    this.onChanged,
    this.onSharedWrite,
  });

  final AppDatabase _database;

  /// Null when nothing should snapshot — the case in every unit test.
  final BackupWriter? backupWriter;

  /// Null when nothing should be deleted from disk — the case in a
  /// database-only test, where the `photos` rows point at paths a fake never
  /// created.
  final PhotoStorage? photoStorage;

  /// Called after every write that lands, which is how the home-screen widget
  /// keeps up. Kept as a bare callback rather than a named collaborator so
  /// this layer still knows nothing about the widget plugin — it only says
  /// "something changed" and lets `main` decide who cares. Null in every unit
  /// test.
  final Future<void> Function()? onChanged;

  /// Called with a group id after a write that produced a shared row, so the
  /// app can push it to the group right away instead of waiting for a manual
  /// sync or the next launch. Kept as a bare callback (not the sync service
  /// itself) so this layer still knows nothing about the transport. Null in
  /// every unit test and in personal mode, where a shared write cannot
  /// happen.
  final void Function(String groupId)? onSharedWrite;

  /// [RestaurantExporter.exportRestaurants], bound in — the `backup.json`
  /// snapshot is built from the very same export every manual share uses, so
  /// the two can't drift apart in what they consider a restaurant's data.
  final Future<List<RestaurantExport>> Function() exportAll;

  /// The push queue that shared writes are recorded in, so the sync engine
  /// can find everything this device changed. Reads and writes the same
  /// drift database as every DAO; private writes never touch it.
  late final PendingSyncStore pending = PendingSyncStore(_database);

  /// Runs what a real app wants after every write that lands: the
  /// `backup.json` snapshot, and telling [onChanged] — the home-screen widget
  /// — that something moved. Either is a no-op when its collaborator wasn't
  /// supplied, which is the case in every unit test.
  Future<void> afterWrite() async {
    final BackupWriter? writer = backupWriter;
    if (writer != null) {
      await writer.write(await exportAll());
    }
    await onChanged?.call();
  }

  /// Fires [onSharedWrite] for a write that produced a shared row, so the app
  /// can push it to the group right away. A private write (null group id) is
  /// a no-op, since there is no group to push it to.
  void notifySharedWrite(String? groupId) {
    if (groupId == null) {
      return;
    }
    onSharedWrite?.call(groupId);
  }

  /// Queues a row for sync when it belongs to a group. A private row has no
  /// group to push to and is left alone, which is what keeps personal mode
  /// exactly the app it was before groups existed.
  Future<void> enqueueIfShared(
    SyncTable table,
    String rowId,
    String? groupId,
  ) async {
    if (groupId == null) {
      return;
    }
    await pending.enqueue(table, rowId, groupId);
  }

  /// Removes the files behind [photos], when a storage is configured. Rows
  /// are always gone by the time this runs, so a missing file is simply
  /// skipped.
  Future<void> deleteFiles(List<Photo> photos) async {
    final PhotoStorage? storage = photoStorage;
    if (storage == null || photos.isEmpty) {
      return;
    }
    for (final Photo photo in photos) {
      await storage.delete(photo.path);
    }
  }
}
