import 'package:drift/drift.dart' show Value;
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/sync/pending_sync_store.dart';
import 'package:eatapp/data/sync/shared_write.dart';
import 'package:eatapp/data/sync/sync_cursor_store.dart';
import 'package:eatapp/data/sync/sync_table.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

/// The repository's side of the sync contract: which writes are attributed to a
/// group, which are queued for push, and how a shared delete differs from a
/// private one. The engine that drains the queue is covered separately, and the
/// transport below it never runs here — this is all local.
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late PendingSyncStore pending;

  const String groupId = 'g1';
  const String userId = 'u1';
  const SharedWrite shared = SharedWrite(groupId: groupId, createdBy: userId);

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    pending = PendingSyncStore(db);
  });

  tearDown(() => db.close());

  /// A restaurant row already belonging to the group — the shape the group UI
  /// will insert, in contrast to the private `restaurant(...)` test helper.
  Restaurant sharedRestaurant({required String id, String name = 'Shared'}) =>
      restaurant(id: id, name: name).copyWith(
        groupId: Value<String?>(groupId),
        createdBy: Value<String?>(userId),
      );

  Future<List<PendingSync>> queue() => pending.pendingForGroup(groupId);

  Future<void> clearQueue() => db.delete(db.pendingSyncs).go();

  group('writes', () {
    test('a private insert queues nothing', () async {
      await repository.insert(restaurant(id: 'p', name: 'Private'));

      expect(await queue(), isEmpty);
    });

    test('a shared insert queues the restaurant and its membership', () async {
      await repository.insert(sharedRestaurant(id: 'r1'));

      final List<PendingSync> entries = await queue();
      expect(
        entries.map((PendingSync e) => e.sharedTable).toSet(),
        <String>{
          SyncTable.restaurants.name,
          SyncTable.restaurantGroups.name,
        },
      );
      expect(
        entries
            .where((PendingSync e) => e.sharedTable == SyncTable.restaurants.name)
            .single
            .rowId,
        'r1',
      );
    });

    test('a shared update queues it again', () async {
      await repository.insert(sharedRestaurant(id: 'r1'));
      await pending.complete(SyncTable.restaurants, <String>['r1']);
      await pending.complete(SyncTable.restaurantGroups, <String>['r1']);

      await repository.update(sharedRestaurant(id: 'r1', name: 'Renamed'));

      expect(
        (await queue())
            .where((PendingSync e) => e.sharedTable == SyncTable.restaurants.name)
            .single
            .rowId,
        'r1',
      );
    });

    test('a shared visit is attributed and queued with its photos', () async {
      await repository.insert(sharedRestaurant(id: 'r1'));
      await clearQueue();

      final String visitId = await repository.addVisit(
        restaurantId: 'r1',
        visitDate: 10,
        rating: 4,
        photoSourcePaths: <String>['a.jpg', 'b.jpg'],
        shared: shared,
      );

      final Visit visit = await db.select(db.visits).getSingle();
      expect(visit.groupId, groupId);
      expect(visit.createdBy, userId);

      final List<Photo> photos = await db.select(db.photos).get();
      expect(photos, hasLength(2));
      expect(photos.every((Photo p) => p.groupId == groupId), isTrue);

      final List<PendingSync> entries = await queue();
      expect(
        entries
            .where((PendingSync e) => e.sharedTable == SyncTable.visits.name)
            .single
            .rowId,
        visitId,
      );
      expect(
        entries.where((PendingSync e) => e.sharedTable == SyncTable.photos.name),
        hasLength(2),
      );
    });

    test('a private visit stays private and unqueued', () async {
      await repository.insert(restaurant(id: 'p', name: 'Private'));

      await repository.addVisit(
        restaurantId: 'p',
        visitDate: 10,
        rating: 4,
        photoSourcePaths: <String>['a.jpg'],
      );

      final Visit visit = await db.select(db.visits).getSingle();
      expect(visit.groupId, isNull);
      expect(visit.createdBy, isNull);
      expect(await queue(), isEmpty);
    });

    test('a shared restaurant photo is attributed and queued', () async {
      await repository.insert(sharedRestaurant(id: 'r1'));
      await clearQueue();

      await repository.addRestaurantPhotos(
        'r1',
        <String>['p.jpg'],
        shared: shared,
      );

      final Photo photo = await db.select(db.photos).getSingle();
      expect(photo.groupId, groupId);
      expect(photo.createdBy, userId);
      expect(
        (await queue()).where(
          (PendingSync e) => e.sharedTable == SyncTable.photos.name,
        ),
        hasLength(1),
      );
    });
  });

  group('deletes', () {
    test('a private delete is a hard delete and queues nothing', () async {
      await repository.insert(restaurant(id: 'p', name: 'Private'));

      await repository.delete('p');

      expect(await db.select(db.restaurants).get(), isEmpty);
      expect(await queue(), isEmpty);
    });

    test('a shared delete tombstones the restaurant, its visits and photos', () async {
      await repository.insert(sharedRestaurant(id: 'r1'));
      await repository.addVisit(
        restaurantId: 'r1',
        visitDate: 10,
        rating: 4,
        photoSourcePaths: <String>['v.jpg'],
        shared: shared,
      );
      await repository.addRestaurantPhotos(
        'r1',
        <String>['r.jpg'],
        shared: shared,
      );
      await clearQueue();

      await repository.delete('r1');

      // The rows survive as tombstones...
      expect((await db.select(db.restaurants).getSingle()).deletedAt, isNotNull);
      expect((await db.select(db.visits).getSingle()).deletedAt, isNotNull);
      for (final Photo photo in await db.select(db.photos).get()) {
        expect(photo.deletedAt, isNotNull);
      }
      // ...disappear from every read...
      expect(await repository.getAllRestaurants(), isEmpty);
      // ...and every tombstone is queued so a push tells the group.
      expect(
        (await queue()).map((PendingSync e) => e.sharedTable).toSet(),
        <String>{
          SyncTable.restaurants.name,
          SyncTable.restaurantGroups.name,
          SyncTable.visits.name,
          SyncTable.photos.name,
        },
      );
    });

    test('a shared visit delete tombstones it and queues it', () async {
      await repository.insert(sharedRestaurant(id: 'r1'));
      final String visitId = await repository.addVisit(
        restaurantId: 'r1',
        visitDate: 10,
        rating: 4,
        shared: shared,
      );
      await clearQueue();

      await repository.deleteVisit(visitId);

      expect((await db.select(db.visits).getSingle()).deletedAt, isNotNull);
      expect(await repository.observeVisitsForRestaurant('r1').first, isEmpty);
      expect(
        (await queue())
            .where((PendingSync e) => e.sharedTable == SyncTable.visits.name)
            .single
            .rowId,
        visitId,
      );
    });
  });

  group('the single-visit rewrite', () {
    test('tombstones a shared visit when the form clears it', () async {
      await repository.insert(sharedRestaurant(id: 'r1'));
      await repository.saveSingleVisit(
        restaurantId: 'r1',
        visited: true,
        rating: 4,
        shared: shared,
      );
      final String visitId = (await db.select(db.visits).getSingle()).id;
      await clearQueue();

      await repository.saveSingleVisit(
        restaurantId: 'r1',
        visited: false,
        rating: 0,
        shared: shared,
      );

      final Visit row = await db.select(db.visits).getSingle();
      expect(row.id, visitId);
      expect(row.deletedAt, isNotNull);
      expect((await queue()).single.rowId, visitId);
    });

    test('revives the same shared visit row when re-saved', () async {
      await repository.insert(sharedRestaurant(id: 'r1'));
      await repository.saveSingleVisit(
        restaurantId: 'r1',
        visited: true,
        rating: 3,
        shared: shared,
      );
      final String visitId = (await db.select(db.visits).getSingle()).id;

      await repository.saveSingleVisit(
        restaurantId: 'r1',
        visited: true,
        rating: 5,
        shared: shared,
      );

      final List<Visit> rows = await db.select(db.visits).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, visitId);
      expect(rows.single.rating, 5);
      expect(rows.single.deletedAt, isNull);
      expect(rows.single.groupId, groupId);
    });
  });

  group('the auto-push hook', () {
    late List<String> notified;
    late RestaurantRepository notifying;

    setUp(() {
      notified = <String>[];
      notifying = RestaurantRepository(db, onSharedWrite: notified.add);
    });

    test('a shared insert fires the hook once with the group id', () async {
      await notifying.insert(sharedRestaurant(id: 'r1'));

      expect(notified, <String>[groupId]);
    });

    test('a private insert never fires the hook', () async {
      await notifying.insert(restaurant(id: 'p', name: 'Private'));

      expect(notified, isEmpty);
    });

    test('a shared visit and its photos fire the hook once', () async {
      await notifying.insert(sharedRestaurant(id: 'r1'));
      notified.clear();

      await notifying.addVisit(
        restaurantId: 'r1',
        visitDate: 10,
        rating: 4,
        photoSourcePaths: <String>['a.jpg'],
        shared: shared,
      );

      expect(notified, <String>[groupId]);
    });

    test('a shared delete fires the hook', () async {
      await notifying.insert(sharedRestaurant(id: 'r1'));
      notified.clear();

      await notifying.delete('r1');

      expect(notified, <String>[groupId]);
    });
  });

  group('purgeGroup', () {
    test('drops the group rows, its queue and its cursor, leaving others', () async {
      // The group being purged: a restaurant, a visit and two photos.
      await repository.insert(sharedRestaurant(id: 'r1'));
      await repository.addVisit(
        restaurantId: 'r1',
        visitDate: 10,
        rating: 4,
        photoSourcePaths: <String>['v.jpg'],
        shared: shared,
      );
      await repository.addRestaurantPhotos(
        'r1',
        <String>['r.jpg'],
        shared: shared,
      );
      await SyncCursorStore(db).advance(groupId, '2026-01-01T00:00:00Z');

      // A second group that must survive the purge untouched.
      await repository.insert(
        restaurant(id: 'r2', name: 'Other').copyWith(
          groupId: const Value<String?>('g2'),
          createdBy: const Value<String?>('u2'),
        ),
      );
      await SyncCursorStore(db).advance('g2', '2026-01-02T00:00:00Z');

      await repository.purgeGroup(groupId);

      expect(
        <String>[for (final Restaurant r in await db.select(db.restaurants).get()) r.id],
        <String>['r2'],
      );
      expect(await db.select(db.visits).get(), isEmpty);
      expect(await db.select(db.photos).get(), isEmpty);
      // The dead group's queue and cursor are gone...
      expect(await pending.pendingForGroup(groupId), isEmpty);
      expect(await SyncCursorStore(db).read(groupId), isNull);
      // ...while the other group keeps both.
      expect(await SyncCursorStore(db).read('g2'), '2026-01-02T00:00:00Z');
      expect(await pending.pendingForGroup('g2'), isNotEmpty);
    });
  });
}
