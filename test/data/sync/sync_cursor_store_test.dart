import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/sync/sync_cursor_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SyncCursorStore store;

  setUp(() {
    db = AppDatabase.memory();
    store = SyncCursorStore(db);
  });

  tearDown(() => db.close());

  test('read returns null before anything has been pulled', () async {
    expect(await store.read('g1'), isNull);
  });

  test('advance stores a cursor that read returns', () async {
    await store.advance('g1', '2026-09-27T10:22:51.924Z');
    expect(await store.read('g1'), '2026-09-27T10:22:51.924Z');
  });

  test('advancing again replaces the previous cursor', () async {
    await store.advance('g1', '2026-09-27T10:00:00.000Z');
    await store.advance('g1', '2026-09-27T11:00:00.000Z');
    expect(await store.read('g1'), '2026-09-27T11:00:00.000Z');
  });

  test('cursors for different groups stay independent', () async {
    await store.advance('g1', '2026-09-27T10:00:00.000Z');
    await store.advance('g2', '2026-09-27T11:00:00.000Z');
    expect(await store.read('g1'), '2026-09-27T10:00:00.000Z');
    expect(await store.read('g2'), '2026-09-27T11:00:00.000Z');
  });
}
