import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/sync/pending_sync_store.dart';
import 'package:eatapp/data/sync/sync_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PendingSyncStore store;

  setUp(() {
    db = AppDatabase.memory();
    store = PendingSyncStore(db);
  });

  tearDown(() => db.close());

  test('enqueue stores one entry under the group', () async {
    await store.enqueue(SyncTable.restaurants, 'r1', 'g1');

    final entries = await store.pendingForGroup('g1');
    expect(entries, hasLength(1));
    expect(entries.single.sharedTable, 'restaurants');
    expect(entries.single.rowId, 'r1');
    expect(entries.single.groupId, 'g1');
  });

  test('pendingForGroup orders restaurants, then visits, then photos', () async {
    await store.enqueue(SyncTable.photos, 'p1', 'g1');
    await store.enqueue(SyncTable.visits, 'v1', 'g1');
    await store.enqueue(SyncTable.restaurants, 'r1', 'g1');

    final entries = await store.pendingForGroup('g1');
    expect(
      entries.map((e) => e.sharedTable).toList(),
      <String>['restaurants', 'visits', 'photos'],
    );
  });

  test('writing the same row twice coalesces and keeps the latest group', () async {
    await store.enqueue(SyncTable.restaurants, 'r1', 'g1');
    await store.enqueue(SyncTable.restaurants, 'r1', 'g2');

    expect(await store.pendingForGroup('g1'), isEmpty);
    final entries = await store.pendingForGroup('g2');
    expect(entries, hasLength(1));
    expect(entries.single.groupId, 'g2');
  });

  test('pendingForGroup only returns the requested group', () async {
    await store.enqueue(SyncTable.restaurants, 'r1', 'g1');
    await store.enqueue(SyncTable.restaurants, 'r2', 'g2');

    expect(
      (await store.pendingForGroup('g1')).map((e) => e.rowId),
      <String>['r1'],
    );
    expect(
      (await store.pendingForGroup('g2')).map((e) => e.rowId),
      <String>['r2'],
    );
  });

  test('complete removes only the given table and ids', () async {
    await store.enqueue(SyncTable.restaurants, 'r1', 'g1');
    await store.enqueue(SyncTable.restaurants, 'r2', 'g1');
    await store.enqueue(SyncTable.visits, 'v1', 'g1');

    await store.complete(SyncTable.restaurants, <String>['r1']);

    final entries = await store.pendingForGroup('g1');
    expect(
      entries.map((e) => e.sharedTable).toList(),
      <String>['restaurants', 'visits'],
    );
    expect(entries.first.rowId, 'r2');
    expect(entries.last.rowId, 'v1');
  });

  test('enqueueAll with nothing is a no-op', () async {
    await store.enqueueAll(const <PendingSync>[]);
    expect(await store.pendingForGroup('g1'), isEmpty);
  });
}
