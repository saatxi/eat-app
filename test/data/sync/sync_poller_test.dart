import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/sync/sync_poller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';
import 'recording_sync_service.dart';

/// The poller's contract: it pulls the selected group on its own timer, stops
/// when nothing is selected, and never stacks timers. `testWidgets` gives the
/// body a fake clock, so `tester.pump(Duration)` advances the interval without
/// waiting in real time.
void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('polls the selected group once per interval', (
    WidgetTester tester,
  ) async {
    final RecordingSyncService service = RecordingSyncService(db);
    final SyncPoller poller = SyncPoller(
      service,
      interval: const Duration(seconds: 10),
    );

    poller.setGroup('g1');
    expect(service.syncedGroups, isEmpty, reason: 'no immediate tick');

    await tester.pump(const Duration(seconds: 30));
    expect(service.syncedGroups, <String>['g1', 'g1', 'g1']);

    poller.dispose();
  });

  testWidgets('clearing the group stops the polling', (
    WidgetTester tester,
  ) async {
    final RecordingSyncService service = RecordingSyncService(db);
    final SyncPoller poller = SyncPoller(
      service,
      interval: const Duration(seconds: 10),
    );

    poller.setGroup('g1');
    await tester.pump(const Duration(seconds: 10));
    expect(service.syncedGroups, hasLength(1));

    poller.setGroup(null);
    await tester.pump(const Duration(minutes: 1));
    expect(service.syncedGroups, hasLength(1), reason: 'nothing selected');

    poller.dispose();
  });

  testWidgets('switching groups polls the new one', (
    WidgetTester tester,
  ) async {
    final RecordingSyncService service = RecordingSyncService(db);
    final SyncPoller poller = SyncPoller(
      service,
      interval: const Duration(seconds: 10),
    );

    poller.setGroup('g1');
    await tester.pump(const Duration(seconds: 10));
    poller.setGroup('g2');
    await tester.pump(const Duration(seconds: 10));

    expect(service.syncedGroups, <String>['g1', 'g2']);

    poller.dispose();
  });

  testWidgets('re-selecting the same group does not stack timers', (
    WidgetTester tester,
  ) async {
    final RecordingSyncService service = RecordingSyncService(db);
    final SyncPoller poller = SyncPoller(
      service,
      interval: const Duration(seconds: 10),
    );

    poller.setGroup('g1');
    poller.setGroup('g1');
    await tester.pump(const Duration(seconds: 10));

    expect(service.syncedGroups, <String>['g1'], reason: 'one timer only');

    poller.dispose();
  });
}
