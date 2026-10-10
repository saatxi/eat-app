import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/sync/pending_sync_store.dart';
import 'package:eatapp/data/sync/sync_table.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

/// The restaurant↔group membership: one canonical restaurant shared into
/// several groups, and what the list shows under each.
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
  });

  tearDown(() => db.close());

  Restaurant sharedIn(String groupId) => restaurant(id: 'r1', name: 'Shared')
      .copyWith(
        groupId: Value<String?>(groupId),
        createdBy: const Value<String?>('u1'),
      );

  Future<List<String>> idsIn(String? groupId) async =>
      (await repository.observeFiltered(groupId: groupId).first)
          .map((Restaurant r) => r.id)
          .toList();

  test('a restaurant shared into two groups shows under both', () async {
    await repository.insert(sharedIn('g1'));

    await repository.setRestaurantGroups(
      restaurantId: 'r1',
      groupIds: <String>{'g1', 'g2'},
      createdBy: 'u1',
    );

    expect(await idsIn('g1'), contains('r1'));
    expect(await idsIn('g2'), contains('r1'));
    expect(await idsIn(null), isEmpty, reason: 'it is no longer personal');
    expect(
      (await repository.groupIdsForRestaurant('r1')).toSet(),
      <String>{'g1', 'g2'},
    );
  });

  test('dropping the last membership makes it personal again', () async {
    await repository.insert(sharedIn('g1'));
    await repository.setRestaurantGroups(
      restaurantId: 'r1',
      groupIds: <String>{'g1', 'g2'},
      createdBy: 'u1',
    );

    await repository.setRestaurantGroups(
      restaurantId: 'r1',
      groupIds: <String>{},
      createdBy: 'u1',
    );

    expect(await idsIn('g1'), isEmpty);
    expect(await idsIn('g2'), isEmpty);
    expect(await idsIn(null), contains('r1'));
    expect(await repository.groupIdsForRestaurant('r1'), isEmpty);
  });

  group('addRestaurantsToGroups', () {
    Future<List<PendingSync>> queued(String groupId) =>
        PendingSyncStore(db).pendingForGroup(groupId);

    test('shares personal restaurants, giving each a home group', () async {
      await repository.insert(restaurant(id: 'a', name: 'A'));
      await repository.insert(restaurant(id: 'b', name: 'B'));

      await repository.addRestaurantsToGroups(
        restaurantIds: <String>{'a', 'b'},
        groupIds: <String>{'g1'},
        createdBy: 'u1',
      );

      expect(await idsIn('g1'), unorderedEquals(<String>['a', 'b']));
      expect(await idsIn(null), isEmpty);
      final Restaurant? a = await db.restaurantDao.getById('a');
      expect(a?.groupId, 'g1');
      expect(a?.createdBy, 'u1');
      final List<PendingSync> entries = await queued('g1');
      expect(
        <(String, String)>{
          for (final PendingSync e in entries) (e.sharedTable, e.rowId),
        },
        <(String, String)>{
          (SyncTable.restaurants.name, 'a'),
          (SyncTable.restaurants.name, 'b'),
          (SyncTable.restaurantGroups.name, 'a'),
          (SyncTable.restaurantGroups.name, 'b'),
        },
      );
    });

    test('keeps the groups a restaurant was already in', () async {
      await repository.insert(sharedIn('g1'));

      await repository.addRestaurantsToGroups(
        restaurantIds: <String>{'r1'},
        groupIds: <String>{'g2'},
        createdBy: 'u2',
      );

      expect(
        (await repository.groupIdsForRestaurant('r1')).toSet(),
        <String>{'g1', 'g2'},
      );
      final Restaurant? row = await db.restaurantDao.getById('r1');
      expect(row?.groupId, 'g1', reason: 'the home group does not move');
      expect(row?.createdBy, 'u1', reason: 'the author is never reassigned');
    });

    test('revives a membership that had been dropped', () async {
      await repository.insert(sharedIn('g1'));
      await repository.setRestaurantGroups(
        restaurantId: 'r1',
        groupIds: <String>{'g1', 'g2'},
        createdBy: 'u1',
      );
      await repository.setRestaurantGroups(
        restaurantId: 'r1',
        groupIds: <String>{'g1'},
        createdBy: 'u1',
      );

      await repository.addRestaurantsToGroups(
        restaurantIds: <String>{'r1'},
        groupIds: <String>{'g2'},
        createdBy: 'u2',
      );

      expect(await idsIn('g2'), contains('r1'));
      final RestaurantGroup membership = await (db.select(db.restaurantGroups)
            ..where((t) => t.restaurantId.equals('r1') & t.groupId.equals('g2')))
          .getSingle();
      expect(membership.deletedAt, isNull);
      expect(membership.createdBy, 'u1', reason: 'the first sharer is kept');
    });
  });

  test('a private restaurant is not in any group', () async {
    await repository.insert(restaurant(id: 'p', name: 'Private'));

    expect(await idsIn(null), contains('p'));
    expect(await idsIn('g1'), isEmpty);
    expect(await repository.groupIdsForRestaurant('p'), isEmpty);
  });

  group('likelyGroupDuplicates', () {
    Future<void> shareInto(String groupId, Restaurant row) async {
      await repository.insert(row);
      await repository.addRestaurantsToGroups(
        restaurantIds: <String>{row.id},
        groupIds: <String>{groupId},
        createdBy: 'u1',
      );
    }

    Future<List<String>> duplicatesOf(
      Set<String> restaurantIds,
      Set<String> groupIds,
    ) async => <String>[
      for (final Restaurant r in await repository.likelyGroupDuplicatesOf(
        restaurantIds: restaurantIds,
        groupIds: groupIds,
      ))
        r.id,
    ];

    test('flags a personal copy of a restaurant the group has', () async {
      await shareInto('g1', restaurant(id: 'old', name: 'Cal Serrats'));
      await repository.insert(restaurant(id: 'new', name: ' cal serrats '));
      await repository.insert(restaurant(id: 'other', name: 'Can Jaume'));

      expect(
        await duplicatesOf(<String>{'new', 'other'}, <String>{'g1'}),
        <String>['new'],
      );
    });

    test('only looks in the groups asked about', () async {
      await shareInto('g1', restaurant(id: 'old', name: 'Cal Serrats'));
      await repository.insert(restaurant(id: 'new', name: 'Cal Serrats'));

      expect(await duplicatesOf(<String>{'new'}, <String>{'g2'}), isEmpty);
    });

    test('a different address is not a duplicate', () async {
      await shareInto(
        'g1',
        restaurant(id: 'old', name: 'Can Jaume', streetAddress: 'Major 1'),
      );
      await repository.insert(
        restaurant(id: 'new', name: 'Can Jaume', streetAddress: 'Mar 9'),
      );

      expect(await duplicatesOf(<String>{'new'}, <String>{'g1'}), isEmpty);
    });

    test('a restaurant already in the group is not asked about', () async {
      // Two copies already in the group: re-adding either changes nothing.
      await shareInto('g1', restaurant(id: 'a', name: 'Xeflis'));
      await shareInto('g1', restaurant(id: 'b', name: 'Xeflis'));

      expect(await duplicatesOf(<String>{'a', 'b'}, <String>{'g1'}), isEmpty);
    });

    test('a deleted or removed group restaurant does not count', () async {
      await shareInto('g1', restaurant(id: 'gone', name: 'Pura Brasa'));
      await repository.delete('gone');
      await shareInto('g1', restaurant(id: 'left', name: 'Feliz 2'));
      await repository.setRestaurantGroups(
        restaurantId: 'left',
        groupIds: <String>{},
        createdBy: 'u1',
      );
      await repository.insert(restaurant(id: 'n1', name: 'Pura Brasa'));
      await repository.insert(restaurant(id: 'n2', name: 'Feliz 2'));

      expect(await duplicatesOf(<String>{'n1', 'n2'}, <String>{'g1'}), isEmpty);
    });
  });
}
