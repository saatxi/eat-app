import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

/// [StatsRepository] on its own — constructed directly rather than reached
/// through [RestaurantRepository], to prove the split genuinely stands alone.
void main() {
  late AppDatabase db;
  late StatsRepository stats;

  setUp(() async {
    db = createTestDatabase();
    stats = StatsRepository(db);
    final RestaurantRepository repository = RestaurantRepository(db);
    await repository.insert(restaurant(id: 'a', name: 'Visited'));
    await repository.insert(restaurant(id: 'b', name: 'Want to try'));
    await repository.addVisit(restaurantId: 'a', visitDate: 1, rating: 4);
  });

  tearDown(() => db.close());

  test('counts and averages only the visited restaurants', () async {
    expect(await stats.observeTotalCount().first, 2);
    expect(await stats.observeVisitedCount().first, 1);
    expect(await stats.observeAverageRating().first, 4);
  });

  test('getRandomWantToTry only ever returns a restaurant with no visits',
      () async {
    final Restaurant? pick = await stats.getRandomWantToTry();
    expect(pick?.id, 'b');
  });
}
