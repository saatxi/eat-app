import 'package:drift/drift.dart' show Value;
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/models/stats_projections.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_test_utils.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() => db.close());

  Future<void> seedRestaurants() async {
    await db.restaurantDao.insertRestaurant(restaurant(id: 'a', name: 'Alpha'));
    await db.restaurantDao.insertRestaurant(restaurant(id: 'b', name: 'Beta'));
  }

  test('observeVisitsForRestaurant returns the newest first', () async {
    await seedRestaurants();
    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 3),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v2', restaurantId: 'a', visitDate: 3000, rating: 5),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v3', restaurantId: 'a', visitDate: 2000, rating: 4),
    );
    await db.visitDao.insertVisit(
      visit(id: 'other', restaurantId: 'b', visitDate: 9000, rating: 1),
    );

    expect(
      (await db.visitDao.observeVisitsForRestaurant('a').first)
          .map((Visit v) => v.id)
          .toList(),
      <String>['v2', 'v3', 'v1'],
    );
  });

  test('getLatestVisit returns the newest one, or null', () async {
    await seedRestaurants();
    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 3),
    );
    await db.visitDao.insertVisit(
      visit(
        id: 'v2',
        restaurantId: 'a',
        visitDate: 3000,
        rating: 5,
        notes: 'ask for the burrata',
      ),
    );

    final Visit? latest = await db.visitDao.getLatestVisit('a');
    expect(latest!.id, 'v2');
    expect(latest.notes, 'ask for the burrata');
    expect(await db.visitDao.getLatestVisit('b'), isNull);
  });

  test('observeLatestVisitByRestaurantId keeps one row per restaurant', () async {
    await seedRestaurants();
    await db.visitDao.insertVisit(
      visit(id: 'old', restaurantId: 'a', visitDate: 1000, rating: 2),
    );
    await db.visitDao.insertVisit(
      visit(id: 'new', restaurantId: 'a', visitDate: 4000, rating: 5),
    );
    await db.visitDao.insertVisit(
      visit(id: 'only', restaurantId: 'b', visitDate: 2000, rating: 3),
    );

    final Map<String, Visit> byRestaurant = <String, Visit>{
      for (final Visit v in await db.visitDao
          .observeLatestVisitByRestaurantId()
          .first)
        v.restaurantId: v,
    };
    expect(byRestaurant.keys, <String>['a', 'b']);
    expect(byRestaurant['a']!.id, 'new');
    expect(byRestaurant['b']!.id, 'only');
  });

  test('observeVisitedCount counts distinct restaurants', () async {
    await seedRestaurants();
    expect(await db.visitDao.observeVisitedCount().first, 0);

    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 3),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v2', restaurantId: 'a', visitDate: 2000, rating: 5),
    );

    expect(await db.visitDao.observeVisitedCount().first, 1);
  });

  test('observeAverageRating averages every visit, null when empty', () async {
    await seedRestaurants();
    expect(await db.visitDao.observeAverageRating().first, isNull);

    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 4),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v2', restaurantId: 'b', visitDate: 2000, rating: 5),
    );

    expect(await db.visitDao.observeAverageRating().first, 4.5);
  });

  test('observeAllVisitDates returns every date in ascending order', () async {
    await seedRestaurants();
    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 3000, rating: 3),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v2', restaurantId: 'b', visitDate: 1000, rating: 3),
    );

    expect(await db.visitDao.observeAllVisitDates().first, <int>[1000, 3000]);
  });

  test('observeAllVisitDateRatings pairs each date with its rating', () async {
    await seedRestaurants();
    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 3000, rating: 5),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v2', restaurantId: 'b', visitDate: 1000, rating: 2),
    );

    final List<VisitDateRating> rows =
        await db.visitDao.observeAllVisitDateRatings().first;
    expect(rows, hasLength(2));
    expect(rows.first.visitDate, 1000);
    expect(rows.first.rating, 2);
    expect(rows.last.visitDate, 3000);
    expect(rows.last.rating, 5);
  });

  test('updateVisit writes the new values in place', () async {
    await seedRestaurants();
    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 3),
    );
    final Visit row = (await db.visitDao.getLatestVisit('a'))!;

    // `notes` is nullable, so drift's generated `copyWith` wraps it in a
    // `Value` — `Value.absent()` meaning "leave it alone".
    await db.visitDao.updateVisit(
      row.copyWith(rating: 5, notes: const Value<String?>('better')),
    );

    final Visit updated = (await db.visitDao.getLatestVisit('a'))!;
    expect(updated.id, 'v1');
    expect(updated.rating, 5);
    expect(updated.notes, 'better');
  });

  test('deleteVisit removes one visit and nothing else', () async {
    await seedRestaurants();
    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 3),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v2', restaurantId: 'a', visitDate: 2000, rating: 4),
    );

    await db.visitDao.deleteVisit('v1');

    expect(
      (await db.visitDao.observeVisitsForRestaurant('a').first)
          .map((Visit v) => v.id)
          .toList(),
      <String>['v2'],
    );
  });

  test('deleteAllVisitsForRestaurant makes it want-to-try again', () async {
    await seedRestaurants();
    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 3),
    );

    await db.visitDao.deleteAllVisitsForRestaurant('a');

    expect(await db.visitDao.observeVisitsForRestaurant('a').first, isEmpty);
    expect(await db.visitDao.observeVisitedCount().first, 0);
  });

  test('deleting a restaurant cascades to its visits', () async {
    await seedRestaurants();
    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 3),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v2', restaurantId: 'b', visitDate: 1000, rating: 3),
    );

    await db.restaurantDao.deleteRestaurant('a');

    expect(
      (await db.visitDao.getAllVisits()).map((Visit v) => v.id).toList(),
      <String>['v2'],
    );
  });

  test('getAllVisits returns every visit', () async {
    await seedRestaurants();
    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 3),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v2', restaurantId: 'b', visitDate: 2000, rating: 4),
    );

    expect(await db.visitDao.getAllVisits(), hasLength(2));
  });
}
