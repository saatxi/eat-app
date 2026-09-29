import 'dart:async';

import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/sync/pending_sync_store.dart';
import 'package:eatapp/data/sync/sync_cursor_store.dart';
import 'package:eatapp/data/sync/sync_engine.dart';
import 'package:eatapp/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';
import 'fake_sync_transport.dart';

/// An engine whose [syncGroup] blocks until the test releases it, so a second
/// request can be made while the first is still in flight — the exact race the
/// service has to coalesce.
class _BlockingEngine extends SyncEngine {
  _BlockingEngine(AppDatabase db)
    : super(
        database: db,
        pending: PendingSyncStore(db),
        cursors: SyncCursorStore(db),
        transport: FakeSyncTransport(),
      );

  final List<Completer<void>> runs = <Completer<void>>[];
  final List<String> groups = <String>[];

  @override
  Future<void> syncGroup(String groupId) {
    groups.add(groupId);
    final Completer<void> completer = Completer<void>();
    runs.add(completer);
    return completer.future;
  }
}

void main() {
  late AppDatabase db;
  late _BlockingEngine engine;
  late SyncService service;

  setUp(() {
    db = createTestDatabase();
    engine = _BlockingEngine(db);
    service = SyncService(engine);
  });

  tearDown(() {
    service.dispose();
    db.close();
  });

  test('requests during an in-flight run coalesce into one extra pass',
      () async {
    final Future<void> first = service.syncGroup('g1');
    await Future<void>.delayed(Duration.zero);
    expect(engine.groups, <String>['g1']);

    // Two more requests land while the first run is still in flight.
    unawaited(service.syncGroup('g1'));
    unawaited(service.syncGroup('g1'));
    await Future<void>.delayed(Duration.zero);
    expect(engine.groups, <String>['g1'], reason: 'not run concurrently');

    // Releasing the first run lets the loop notice the requests and run once
    // more — never a third time, however many were coalesced.
    engine.runs[0].complete();
    await Future<void>.delayed(Duration.zero);
    expect(engine.groups, <String>['g1', 'g1']);

    engine.runs[1].complete();
    await first;
    expect(engine.groups, <String>['g1', 'g1']);
  });

  test('a request after a run completes starts a fresh run', () async {
    final Future<void> first = service.syncGroup('g1');
    engine.runs[0].complete();
    await first;

    final Future<void> second = service.syncGroup('g1');
    await Future<void>.delayed(Duration.zero);
    expect(engine.groups, <String>['g1', 'g1']);

    engine.runs[1].complete();
    await second;
  });
}
