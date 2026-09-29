import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/sync/pending_sync_store.dart';
import 'package:eatapp/data/sync/sync_cursor_store.dart';
import 'package:eatapp/data/sync/sync_engine.dart';
import 'package:eatapp/data/sync/sync_service.dart';

import 'fake_sync_transport.dart';

/// A [SyncService] that only records which group was synced.
///
/// The UI triggers that ask for a sync care about *that* one was requested; a
/// real engine would drag the database into a `testWidgets` fake-async body (the
/// trap the project's notes warn about), so the engine it holds is never used.
class RecordingSyncService extends SyncService {
  RecordingSyncService(AppDatabase db)
    : super(
        SyncEngine(
          database: db,
          pending: PendingSyncStore(db),
          cursors: SyncCursorStore(db),
          transport: FakeSyncTransport(),
        ),
      );

  /// The group ids [syncGroup] was asked for, in order.
  final List<String> syncedGroups = <String>[];

  @override
  Future<void> syncGroup(String groupId) async {
    syncedGroups.add(groupId);
    status.value = SyncStatus.succeeded;
  }
}
