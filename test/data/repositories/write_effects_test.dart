import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/write_effects.dart';
import 'package:eatapp/data/share/backup_writer.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:eatapp/data/sync/sync_table.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';
import '../photo/photo_fakes.dart';

/// The shared after-a-write behaviour every split repository forwards to:
/// the backup snapshot, the home-widget callback, sync queueing and photo
/// file cleanup.
void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());

  tearDown(() => db.close());

  test('afterWrite snapshots through the backup writer and calls onChanged',
      () async {
    final List<List<RestaurantExport>> snapshots = <List<RestaurantExport>>[];
    bool changed = false;
    final WriteEffects effects = WriteEffects(
      db,
      exportAll: () async => const <RestaurantExport>[],
      backupWriter: _RecordingBackupWriter(snapshots),
      onChanged: () async => changed = true,
    );

    await effects.afterWrite();

    expect(snapshots, hasLength(1));
    expect(changed, isTrue);
  });

  test('notifySharedWrite is a no-op for a private (null) group', () async {
    final List<String> notified = <String>[];
    final WriteEffects effects = WriteEffects(
      db,
      exportAll: () async => const <RestaurantExport>[],
      onSharedWrite: notified.add,
    );

    effects.notifySharedWrite(null);
    effects.notifySharedWrite('g1');

    expect(notified, <String>['g1']);
  });

  test('deleteFiles removes each photo through the configured storage',
      () async {
    final FakePhotoStorage storage = FakePhotoStorage();
    final WriteEffects effects = WriteEffects(
      db,
      exportAll: () async => const <RestaurantExport>[],
      photoStorage: storage,
    );

    await effects.deleteFiles(<Photo>[
      photo(id: 'p1', path: '/photos/a.jpg'),
      photo(id: 'p2', path: '/photos/b.jpg'),
    ]);

    expect(storage.deleted, <String>['/photos/a.jpg', '/photos/b.jpg']);
  });

  test('enqueueIfShared queues a shared row and skips a private one',
      () async {
    final WriteEffects effects = WriteEffects(
      db,
      exportAll: () async => const <RestaurantExport>[],
    );

    await effects.enqueueIfShared(SyncTable.restaurants, 'r1', 'g1');
    await effects.enqueueIfShared(SyncTable.restaurants, 'r2', null);

    final List<PendingSync> queued = await effects.pending.pendingForGroup(
      'g1',
    );
    expect(queued.map((PendingSync e) => e.rowId), <String>['r1']);
  });
}

class _RecordingBackupWriter implements BackupWriter {
  _RecordingBackupWriter(this.snapshots);

  final List<List<RestaurantExport>> snapshots;

  @override
  Future<void> write(List<RestaurantExport> restaurants) async {
    snapshots.add(restaurants);
  }
}
