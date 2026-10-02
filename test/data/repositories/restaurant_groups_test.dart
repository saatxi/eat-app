import 'package:drift/drift.dart' show Value;
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
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

  test('a private restaurant is not in any group', () async {
    await repository.insert(restaurant(id: 'p', name: 'Private'));

    expect(await idsIn(null), contains('p'));
    expect(await idsIn('g1'), isEmpty);
    expect(await repository.groupIdsForRestaurant('p'), isEmpty);
  });
}
