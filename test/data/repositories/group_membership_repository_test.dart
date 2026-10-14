import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/group_membership_repository.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/write_effects.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

/// [GroupMembershipRepository] on its own — constructed directly with a bare
/// [WriteEffects], rather than reached through [RestaurantRepository], to
/// prove the split genuinely stands alone.
void main() {
  late AppDatabase db;
  late GroupMembershipRepository membership;

  setUp(() async {
    db = createTestDatabase();
    final WriteEffects effects = WriteEffects(
      db,
      exportAll: () async => const <RestaurantExport>[],
    );
    membership = GroupMembershipRepository(db, effects);
    await RestaurantRepository(db).insert(restaurant(id: 'a', name: 'Shared'));
  });

  tearDown(() => db.close());

  test('setRestaurantGroups adds a membership the Journal can then read back',
      () async {
    await membership.setRestaurantGroups(
      restaurantId: 'a',
      groupIds: <String>{'g1'},
      createdBy: 'u1',
    );

    expect(await membership.groupIdsForRestaurant('a'), <String>['g1']);
  });

  test('a restaurant with the same name is flagged as a likely duplicate',
      () async {
    await membership.setRestaurantGroups(
      restaurantId: 'a',
      groupIds: <String>{'g1'},
      createdBy: 'u1',
    );

    final List<Restaurant> duplicates = await membership.likelyGroupDuplicates(
      candidates: <Restaurant>[restaurant(id: 'b', name: 'Shared')],
      groupIds: <String>{'g1'},
    );

    expect(duplicates.single.id, 'b');
  });
}
