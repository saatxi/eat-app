import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

/// The `onChanged` hook the home-screen widget hangs off. It is the one part of
/// the widget that lives in the repository layer, so it is held here rather than
/// with the widget service, whose platform bridge can't run off-device.
void main() {
  late AppDatabase db;
  late int changes;

  setUp(() {
    db = createTestDatabase();
    changes = 0;
  });

  tearDown(() => db.close());

  RestaurantRepository build() =>
      RestaurantRepository(db, onChanged: () async => changes++);

  test('fires once after a write lands', () async {
    final RestaurantRepository repository = build();

    await repository.insert(restaurant(id: 'a', name: 'A'));

    expect(changes, 1);
  });

  test('fires again after every subsequent write', () async {
    final RestaurantRepository repository = build();

    await repository.insert(restaurant(id: 'a', name: 'A'));
    await repository.update(restaurant(id: 'a', name: 'B'), const <String>[]);
    await repository.delete('a');

    expect(changes, 3);
  });

  test('fires after a bulk delete too', () async {
    final RestaurantRepository repository = build();
    await repository.insert(restaurant(id: 'a', name: 'A'));

    await repository.deleteAll();

    expect(changes, 2);
  });

  test('is optional — a repository with no callback still writes', () async {
    final RestaurantRepository repository = RestaurantRepository(db);

    await repository.insert(restaurant(id: 'a', name: 'A'));

    expect(await repository.getAllRestaurants(), hasLength(1));
  });
}
