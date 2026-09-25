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

  /// Three restaurants, two of them visited.
  Future<void> seed() async {
    await db.restaurantDao.insertRestaurant(
      restaurant(
        id: 'a',
        name: 'Alpha',
        cuisineType: 'italian',
        city: 'Roma',
        priceRange: 2,
      ),
    );
    await db.restaurantDao.insertRestaurant(
      restaurant(
        id: 'b',
        name: 'beta',
        cuisineType: 'japanese',
        city: 'Osaka',
        priceRange: 3,
      ),
    );
    await db.restaurantDao.insertRestaurant(
      restaurant(id: 'c', name: 'Gamma', cuisineType: 'italian'),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 4),
    );
    await db.visitDao.insertVisit(
      visit(id: 'v2', restaurantId: 'b', visitDate: 2000, rating: 5),
    );
  }

  group('observeFiltered', () {
    test('returns everything in name order by default', () async {
      await seed();

      expect(await filteredIds(db), <String>['a', 'b', 'c']);
    });

    test('sorts by the best visit rating, name breaking ties', () async {
      await seed();
      await db.restaurantDao.insertRestaurant(
        restaurant(id: 'd', name: 'Delta', cuisineType: 'asian', priceRange: 1),
      );
      await db.visitDao.insertVisit(
        visit(id: 'v3', restaurantId: 'd', visitDate: 1500, rating: 5),
      );

      expect(await filteredIds(db, sortByRating: true), <String>[
        'b',
        'd',
        'a',
        'c',
      ]);
      // An unrated restaurant sorts last rather than first.
      expect(await filteredIds(db, sortByRating: true, visited: false), <String>[
        'c',
      ]);
    });

    test('matches the folded query against name, cuisine and address', () async {
      await seed();
      await db.restaurantDao.insertRestaurant(
        restaurant(
          id: 'e',
          name: 'Cafè Nou',
          cuisineType: 'cafe',
          streetAddress: 'Plaça Nova',
        ),
      );

      expect(await filteredIds(db, query: 'cafe'), <String>['e']);
      expect(await filteredIds(db, query: 'plaça nova'), <String>['e']);
      expect(await filteredIds(db, query: 'japan'), <String>['b']);
      expect(await filteredIds(db, query: 'Roma'), <String>['a']);
      expect(await filteredIds(db, query: 'nowhere'), isEmpty);
    });

    test('treats % and _ as literal characters', () async {
      await seed();
      await db.restaurantDao.insertRestaurant(
        restaurant(id: 'p', name: '50% off'),
      );

      expect(await filteredIds(db, query: '%'), <String>['p']);
      expect(await filteredIds(db, query: '_'), isEmpty);
    });

    test('filters by the best visit rating', () async {
      await seed();

      expect(await filteredIds(db, minRating: 5), <String>['b']);
      expect(await filteredIds(db, minRating: 4), <String>['a', 'b']);
    });

    test('filters by cuisine, city and price range', () async {
      await seed();

      expect(await filteredIds(db, cuisineType: 'italian'), <String>['a', 'c']);
      expect(await filteredIds(db, city: 'Osaka'), <String>['b']);
      expect(await filteredIds(db, priceRange: 0), <String>['c']);
    });

    test('filters by region and country', () async {
      await db.restaurantDao.insertRestaurant(
        restaurant(id: 'x', name: 'X', region: 'Maresme', country: 'Spain'),
      );
      await db.restaurantDao.insertRestaurant(
        restaurant(id: 'y', name: 'Y', region: 'Barcelonès', country: 'Spain'),
      );

      expect(await filteredIds(db, region: 'Maresme'), <String>['x']);
      expect(await filteredIds(db, country: 'Spain'), <String>['x', 'y']);
    });

    test('separates want-to-try from visited', () async {
      await seed();

      expect(await filteredIds(db, visited: true), <String>['a', 'b']);
      expect(await filteredIds(db, visited: false), <String>['c']);
    });

    test('combines filters rather than or-ing them', () async {
      await seed();

      expect(
        await filteredIds(db, cuisineType: 'italian', visited: true),
        <String>['a'],
      );
    });
  });

  group('distinct values', () {
    test('offers only the cuisine keys actually present', () async {
      await seed();

      expect(await db.restaurantDao.observeCuisineTypes().first, <String>[
        'italian',
        'japanese',
      ]);
    });

    test('offers the cities present, sorted, and skips the nulls', () async {
      await seed();
      await db.restaurantDao.insertRestaurant(
        restaurant(id: 'd', name: 'Delta', city: 'Alacant'),
      );

      expect(await db.restaurantDao.observeCities().first, <String>[
        'Alacant',
        'Osaka',
        'Roma',
      ]);
      expect(await db.restaurantDao.observeRegions().first, isEmpty);
      expect(await db.restaurantDao.observeCountries().first, isEmpty);
    });
  });

  group('crud', () {
    test('round-trips every column', () async {
      await db.restaurantDao.insertRestaurant(
        restaurant(
          id: 'a',
          name: 'Alpha',
          cuisineType: 'italian',
          streetAddress: 'Carrer Nou 1',
          city: 'Mataró',
          region: 'Maresme',
          country: 'Spain',
          priceRange: 3,
          website: 'https://example.com',
          instagram: 'eatapp',
        ),
      );

      final Restaurant? row = await db.restaurantDao.observeById('a').first;
      expect(row, isNotNull);
      expect(row!.streetAddress, 'Carrer Nou 1');
      expect(row.city, 'Mataró');
      expect(row.website, 'https://example.com');
      expect(row.instagram, 'eatapp');
      expect(row.searchText, 'alpha italian carrer nou 1 mataro maresme spain');
      expect(await db.restaurantDao.observeById('missing').first, isNull);
    });

    test('updates in place instead of replacing the row', () async {
      await seed();
      final Restaurant row = (await db.restaurantDao.observeById('a').first)!;

      await db.restaurantDao.updateRestaurant(
        row.copyWith(name: 'Alpha 2', searchText: 'alpha 2 italian'),
      );

      expect((await db.restaurantDao.observeById('a').first)!.name, 'Alpha 2');
      // The visit survived: drift's `replace` (an INSERT OR REPLACE) would have
      // cascade-deleted it.
      expect(
        await db.visitDao.observeVisitsForRestaurant('a').first,
        hasLength(1),
      );
    });

    test('deletes one row and cascades to its visits', () async {
      await seed();

      await db.restaurantDao.deleteRestaurant('a');

      expect(await filteredIds(db), <String>['b', 'c']);
      expect(await db.visitDao.observeVisitsForRestaurant('a').first, isEmpty);
    });

    test('deleteAll clears the table', () async {
      await seed();

      await db.restaurantDao.deleteAllRestaurants();

      expect(await db.restaurantDao.observeTotalCount().first, 0);
      expect(await filteredIds(db), isEmpty);
    });

    test('getAll returns every row in name order', () async {
      await seed();

      expect(
        (await db.restaurantDao.getAll()).map((Restaurant r) => r.id).toList(),
        <String>['a', 'b', 'c'],
      );
    });
  });

  group('statistics', () {
    test('counts the total', () async {
      await seed();

      expect(await db.restaurantDao.observeTotalCount().first, 3);
    });

    test('ranks cuisines by how many restaurants hold them', () async {
      await seed();

      final List<CuisineCount> counts =
          await db.restaurantDao.observeCuisineCounts().first;
      expect(counts.first.cuisineType, 'italian');
      expect(counts.first.count, 2);
      expect(counts.last.cuisineType, 'japanese');
      expect(counts.last.count, 1);
    });

    test('groups the price ranges present', () async {
      await seed();

      final List<PriceRangeCount> counts =
          await db.restaurantDao.observePriceRangeCounts().first;
      expect(
        <int>{for (final PriceRangeCount c in counts) c.priceRange},
        <int>{0, 2, 3},
      );
    });
  });

  group('getRandomWantToTry', () {
    test('picks from the unvisited rows only', () async {
      await seed();

      expect((await db.restaurantDao.getRandomWantToTry())!.id, 'c');
    });

    test('returns null once everything has been visited', () async {
      await db.restaurantDao.insertRestaurant(
        restaurant(id: 'a', name: 'Alpha'),
      );
      await db.visitDao.insertVisit(
        visit(id: 'v', restaurantId: 'a', visitDate: 1, rating: 3),
      );

      expect(await db.restaurantDao.getRandomWantToTry(), isNull);
    });
  });
}
