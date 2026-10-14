import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_exporter.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

/// [RestaurantExporter] on its own — constructed directly rather than
/// reached through [RestaurantRepository], to prove the split genuinely
/// stands alone.
void main() {
  late AppDatabase db;
  late RestaurantExporter exporter;

  setUp(() async {
    db = createTestDatabase();
    exporter = RestaurantExporter(db, favoriteIds: () => <String>{'a'});
    await RestaurantRepository(db).insert(restaurant(id: 'a', name: 'First'));
  });

  tearDown(() => db.close());

  test('carries the favourite flag from favoriteIds', () async {
    final List<RestaurantExport> exported = await exporter.exportRestaurants();

    expect(exported.single.isFavorite, isTrue);
  });
}
