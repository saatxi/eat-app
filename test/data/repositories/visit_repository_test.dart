import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/visit_repository.dart';
import 'package:eatapp/data/repositories/write_effects.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

/// [VisitRepository] on its own — constructed directly with a bare
/// [WriteEffects], rather than reached through [RestaurantRepository], to
/// prove the split genuinely stands alone.
void main() {
  late AppDatabase db;
  late VisitRepository visits;

  setUp(() async {
    db = createTestDatabase();
    final WriteEffects effects = WriteEffects(
      db,
      exportAll: () async => const <RestaurantExport>[],
    );
    visits = VisitRepository(db, effects);
    await RestaurantRepository(db).insert(restaurant(id: 'a', name: 'First'));
  });

  tearDown(() => db.close());

  test('addVisit then updateVisit rewrites the same row', () async {
    final String visitId = await visits.addVisit(
      restaurantId: 'a',
      visitDate: 1000,
      rating: 3,
    );

    await visits.updateVisit(visitId: visitId, visitDate: 2000, rating: 5);

    final Visit row = (await visits.observeVisitsForRestaurant('a').first).single;
    expect(row.id, visitId);
    expect(row.rating, 5);
    expect(row.visitDate, 2000);
  });

  test('deleteVisit removes it', () async {
    final String visitId = await visits.addVisit(
      restaurantId: 'a',
      visitDate: 1000,
      rating: 3,
    );

    await visits.deleteVisit(visitId);

    expect(await visits.observeVisitsForRestaurant('a').first, isEmpty);
  });
}
