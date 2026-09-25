import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/models/restaurant_sort.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

void main() {
  late AppDatabase db;
  late RestaurantRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
  });

  tearDown(() => db.close());

  Future<List<String>> filteredIds({
    String? query,
    int? minRating,
    String? cuisineType,
    RestaurantSort sort = RestaurantSort.name,
    bool? visited,
    String? city,
    String? region,
    String? country,
    int? priceRange,
  }) async {
    final List<Restaurant> rows = await repository
        .observeFiltered(
          query: query,
          minRating: minRating,
          cuisineType: cuisineType,
          sort: sort,
          visited: visited,
          city: city,
          region: region,
          country: country,
          priceRange: priceRange,
        )
        .first;
    return <String>[for (final Restaurant row in rows) row.id];
  }

  group('the search term', () {
    test('is folded, so an unaccented query finds an accented name', () async {
      await repository.insert(restaurant(id: 'a', name: 'Mediterránea'));

      expect(await filteredIds(query: 'mediterranea'), <String>['a']);
    });

    test('is escaped, so a typed % matches itself rather than everything', () async {
      await repository.insert(restaurant(id: 'plain', name: 'Kebab'));
      await repository.insert(restaurant(id: 'literal', name: 'K%b'));

      expect(await filteredIds(query: '%'), <String>['literal']);
    });

    test('is escaped for the underscore too', () async {
      await repository.insert(restaurant(id: 'plain', name: 'Kebab'));
      await repository.insert(restaurant(id: 'literal', name: 'K_b'));

      expect(await filteredIds(query: 'k_b'), <String>['literal']);
    });

    test('finds the street address, city, region and country', () async {
      await repository.insert(
        restaurant(
          id: 'a',
          name: 'Zzz',
          streetAddress: 'Carrer dels Tallers',
          city: 'Barcelona',
          region: 'Catalunya',
          country: 'Espanya',
        ),
      );

      expect(await filteredIds(query: 'tallers'), <String>['a']);
      expect(await filteredIds(query: 'barcelona'), <String>['a']);
      expect(await filteredIds(query: 'catalunya'), <String>['a']);
      expect(await filteredIds(query: 'espanya'), <String>['a']);
    });

    test('a blank string is the same as no filter at all', () async {
      await repository.insert(restaurant(id: 'a', name: 'First'));
      await repository.insert(restaurant(id: 'b', name: 'Second'));

      expect(await filteredIds(query: '   '), <String>['a', 'b']);
      expect(await filteredIds(query: ''), <String>['a', 'b']);
    });
  });

  group('the other filters', () {
    test('a blank cuisine, city, region or country is the same as no filter', () async {
      await repository.insert(
        restaurant(
          id: 'a',
          name: 'First',
          cuisineType: 'italian',
          city: 'Barcelona',
          region: 'Catalunya',
          country: 'Espanya',
        ),
      );

      expect(
        await filteredIds(
          cuisineType: '',
          city: '  ',
          region: '',
          country: ' ',
        ),
        <String>['a'],
      );
    });

    test('the sort order is passed through as a flag, not as SQL', () async {
      await repository.insert(restaurant(id: 'worst', name: 'Worst'));
      await repository.insert(restaurant(id: 'best', name: 'Best'));
      await db.visitDao.insertVisit(
        visit(id: 'v1', restaurantId: 'worst', visitDate: 1, rating: 1),
      );
      await db.visitDao.insertVisit(
        visit(id: 'v2', restaurantId: 'best', visitDate: 2, rating: 5),
      );

      expect(
        await filteredIds(sort: RestaurantSort.rating),
        <String>['best', 'worst'],
      );
      expect(
        await filteredIds(),
        <String>['best', 'worst'],
        reason: 'the name order happens to agree here',
      );
    });
  });

  group('writes', () {
    test('insert stores the row and its tags in one transaction', () async {
      await repository.insert(
        restaurant(id: 'a', name: 'First'),
        tags: <String>['Terraza', 'Para grupos'],
      );

      expect(await repository.observeById('a').first, isNotNull);
      expect(
        await repository.observeTagNames('a').first,
        <String>['Para grupos', 'Terraza'],
      );
    });

    test('update replaces the tags rather than adding to them', () async {
      await repository.insert(
        restaurant(id: 'a', name: 'First'),
        tags: <String>['Terraza'],
      );

      await repository.update(
        restaurant(id: 'a', name: 'Renamed'),
        <String>['Coeliac'],
      );

      expect((await repository.observeById('a').first)!.name, 'Renamed');
      expect(await repository.observeTagNames('a').first, <String>['Coeliac']);
      // The vocabulary is shared, so the tag that is no longer used survives.
      expect(await repository.observeAllTagNames().first, <String>[
        'Coeliac',
        'Terraza',
      ]);
    });

    test('delete cascades to the visits and photos and drops the links', () async {
      await repository.insert(
        restaurant(id: 'a', name: 'First'),
        tags: <String>['Terraza'],
      );
      await repository.addVisit(
        restaurantId: 'a',
        visitDate: 1,
        rating: 4,
        photoPaths: <String>['/photos/1.jpg'],
      );
      await repository.addRestaurantPhotos('a', <String>['/photos/2.jpg']);

      await repository.delete('a');

      expect(await repository.observeById('a').first, isNull);
      expect(await repository.observeVisitsForRestaurant('a').first, isEmpty);
      expect(await repository.observePhotosForRestaurant('a').first, isEmpty);
      expect(await repository.observeTagNames('a').first, isEmpty);
    });

    test('deleteAll also clears the tag vocabulary', () async {
      await repository.insert(
        restaurant(id: 'a', name: 'First'),
        tags: <String>['Terraza'],
      );

      await repository.deleteAll();

      expect(await repository.observeTotalCount().first, 0);
      expect(await repository.observeAllTagNames().first, isEmpty);
    });
  });

  group('visits', () {
    setUp(() async {
      await repository.insert(restaurant(id: 'a', name: 'First'));
    });

    test('addVisit stores one visit together with its photos, in order', () async {
      final String visitId = await repository.addVisit(
        restaurantId: 'a',
        visitDate: 1000,
        rating: 4,
        notes: 'Good',
        priceRange: 2,
        photoPaths: <String>['/photos/a.jpg', '/photos/b.jpg'],
      );

      final List<Visit> visits = await repository
          .observeVisitsForRestaurant('a')
          .first;
      expect(visits, hasLength(1));
      expect(visits.single.id, visitId);
      expect(visits.single.rating, 4);
      expect(visits.single.priceRange, 2);

      final List<Photo> photos = await repository
          .observePhotosForVisit(visitId)
          .first;
      expect(
        <String>[for (final Photo photo in photos) photo.path],
        <String>['/photos/a.jpg', '/photos/b.jpg'],
      );
      expect(
        <int>[for (final Photo photo in photos) photo.position],
        <int>[0, 1],
      );
    });

    test('saveSingleVisit reuses the visit\'s identity, date and price band', () async {
      final String firstId = await repository.addVisit(
        restaurantId: 'a',
        visitDate: 1000,
        rating: 3,
        priceRange: 2,
      );

      await repository.saveSingleVisit(
        restaurantId: 'a',
        visited: true,
        rating: 5,
        notes: 'Better the second time',
      );

      final List<Visit> visits = await repository
          .observeVisitsForRestaurant('a')
          .first;
      expect(visits, hasLength(1));
      expect(
        visits.single.id,
        firstId,
        reason: 're-saving the form must not look like a new visit',
      );
      expect(
        visits.single.visitDate,
        1000,
        reason: 'and must not reset the date to now',
      );
      expect(visits.single.rating, 5);
      expect(visits.single.notes, 'Better the second time');
      expect(
        visits.single.priceRange,
        2,
        reason: 'the form does not ask for it, so it has to be carried over',
      );
    });

    test('saveSingleVisit with visited false clears every visit', () async {
      await repository.addVisit(restaurantId: 'a', visitDate: 1000, rating: 3);
      await repository.addVisit(restaurantId: 'a', visitDate: 2000, rating: 4);

      await repository.saveSingleVisit(
        restaurantId: 'a',
        visited: false,
        rating: 0,
      );

      expect(await repository.observeVisitsForRestaurant('a').first, isEmpty);
    });

    test('saveSingleVisit on a restaurant with no visits starts from now', () async {
      final int before = DateTime.now().millisecondsSinceEpoch;

      await repository.saveSingleVisit(
        restaurantId: 'a',
        visited: true,
        rating: 4,
      );

      final Visit visit = (await repository
          .observeVisitsForRestaurant('a')
          .first).single;
      expect(visit.visitDate, greaterThanOrEqualTo(before));
      expect(visit.priceRange, 0);
    });

    test('observeLatestVisitByRestaurantId keys the newest visit by restaurant', () async {
      await repository.insert(restaurant(id: 'b', name: 'Second'));
      await repository.addVisit(restaurantId: 'a', visitDate: 1000, rating: 1);
      await repository.addVisit(restaurantId: 'a', visitDate: 3000, rating: 5);
      await repository.addVisit(restaurantId: 'b', visitDate: 2000, rating: 2);

      final Map<String, Visit> latest = await repository
          .observeLatestVisitByRestaurantId()
          .first;

      expect(latest.keys.toSet(), <String>{'a', 'b'});
      expect(latest['a']!.visitDate, 3000);
      expect(latest['b']!.visitDate, 2000);
    });

    test('deleteVisit removes one visit and leaves the rest', () async {
      final String first = await repository.addVisit(
        restaurantId: 'a',
        visitDate: 1000,
        rating: 1,
      );
      await repository.addVisit(restaurantId: 'a', visitDate: 2000, rating: 2);

      await repository.deleteVisit(first);

      final List<Visit> visits = await repository
          .observeVisitsForRestaurant('a')
          .first;
      expect(visits, hasLength(1));
      expect(visits.single.visitDate, 2000);
    });
  });

  group('photos', () {
    setUp(() async {
      await repository.insert(restaurant(id: 'a', name: 'First'));
    });

    test('addRestaurantPhotos appends after whatever is already there', () async {
      await repository.addRestaurantPhotos('a', <String>['/photos/a.jpg']);
      await repository.addRestaurantPhotos('a', <String>['/photos/b.jpg']);

      final List<Photo> photos = await repository
          .observePhotosForRestaurant('a')
          .first;
      expect(
        <String>[for (final Photo photo in photos) photo.path],
        <String>['/photos/a.jpg', '/photos/b.jpg'],
      );
      expect(
        <int>[for (final Photo photo in photos) photo.position],
        <int>[0, 1],
      );
      expect(await repository.getRestaurantPhotoPath('a'), '/photos/a.jpg');
    });

    test('addRestaurantPhotos with nothing to add is a no-op', () async {
      await repository.addRestaurantPhotos('a', const <String>[]);

      expect(await repository.observePhotosForRestaurant('a').first, isEmpty);
    });

    test('a visit-level photo is not offered as the restaurant\'s own', () async {
      await repository.addVisit(
        restaurantId: 'a',
        visitDate: 1,
        rating: 3,
        photoPaths: <String>['/photos/visit.jpg'],
      );

      expect(await repository.observePhotosForRestaurant('a').first, isEmpty);
      expect(await repository.getRestaurantPhotoPath('a'), isNull);
    });

    test('deletePhoto removes just that row', () async {
      await repository.addRestaurantPhotos('a', <String>[
        '/photos/a.jpg',
        '/photos/b.jpg',
      ]);
      final Photo first = (await repository
          .observePhotosForRestaurant('a')
          .first).first;

      await repository.deletePhoto(first.id);

      expect(await repository.getRestaurantPhotoPath('a'), '/photos/b.jpg');
    });
  });

  group('tags', () {
    test('observeTagsByRestaurantId groups the links by restaurant', () async {
      await repository.insert(
        restaurant(id: 'a', name: 'First'),
        tags: <String>['Terraza', 'Coeliac'],
      );
      await repository.insert(
        restaurant(id: 'b', name: 'Second'),
        tags: <String>['Terraza'],
      );

      final Map<String, List<String>> byRestaurant = await repository
          .observeTagsByRestaurantId()
          .first;

      // The underlying query has no ORDER BY, so only the grouping is defined.
      expect(byRestaurant['a'], unorderedEquals(<String>['Terraza', 'Coeliac']));
      expect(byRestaurant['b'], <String>['Terraza']);
    });

    test('a restaurant with no tags is simply absent from the map', () async {
      await repository.insert(restaurant(id: 'a', name: 'First'));

      expect(await repository.observeTagsByRestaurantId().first, isEmpty);
    });
  });

  group('statistics', () {
    test('counts and averages only the visited restaurants', () async {
      await repository.insert(restaurant(id: 'a', name: 'First'));
      await repository.insert(restaurant(id: 'b', name: 'Second'));
      await repository.insert(restaurant(id: 'c', name: 'Third'));
      await repository.addVisit(restaurantId: 'a', visitDate: 1, rating: 2);
      await repository.addVisit(restaurantId: 'b', visitDate: 2, rating: 4);

      expect(await repository.observeTotalCount().first, 3);
      expect(await repository.observeVisitedCount().first, 2);
      expect(await repository.observeAverageRating().first, 3.0);
    });

    test('the average is null while nothing has been visited', () async {
      await repository.insert(restaurant(id: 'a', name: 'First'));

      expect(await repository.observeAverageRating().first, isNull);
    });

    test('getRandomWantToTry only ever returns a restaurant with no visits', () async {
      await repository.insert(restaurant(id: 'visited', name: 'Visited'));
      await repository.insert(restaurant(id: 'wanted', name: 'Wanted'));
      await repository.addVisit(restaurantId: 'visited', visitDate: 1, rating: 3);

      expect((await repository.getRandomWantToTry())!.id, 'wanted');
    });

    test('getRandomWantToTry is null when everything has been visited', () async {
      await repository.insert(restaurant(id: 'a', name: 'First'));
      await repository.addVisit(restaurantId: 'a', visitDate: 1, rating: 3);

      expect(await repository.getRandomWantToTry(), isNull);
    });

    test('the cuisine and price-range counts cover every stored row', () async {
      await repository.insert(
        restaurant(id: 'a', name: 'First', cuisineType: 'italian', priceRange: 1),
      );
      await repository.insert(
        restaurant(id: 'b', name: 'Second', cuisineType: 'italian', priceRange: 2),
      );
      await repository.insert(
        restaurant(id: 'c', name: 'Third', cuisineType: 'thai', priceRange: 1),
      );

      final cuisines = await repository.observeCuisineCounts().first;
      expect(
        <String, int>{for (final c in cuisines) c.cuisineType: c.count},
        <String, int>{'italian': 2, 'thai': 1},
      );

      final prices = await repository.observePriceRangeCounts().first;
      expect(
        <int, int>{for (final p in prices) p.priceRange: p.count},
        <int, int>{1: 2, 2: 1},
      );
    });

    test('the tag counts rank the most-used tag first', () async {
      await repository.insert(
        restaurant(id: 'a', name: 'First'),
        tags: <String>['Terraza', 'Coeliac'],
      );
      await repository.insert(
        restaurant(id: 'b', name: 'Second'),
        tags: <String>['Terraza'],
      );

      final tags = await repository.observeTagCounts().first;
      expect(tags.first.name, 'Terraza');
      expect(tags.first.count, 2);
    });

    test('the visit dates and their ratings come back paired, oldest first', () async {
      await repository.insert(restaurant(id: 'a', name: 'First'));
      await repository.addVisit(restaurantId: 'a', visitDate: 3000, rating: 5);
      await repository.addVisit(restaurantId: 'a', visitDate: 1000, rating: 2);

      expect(await repository.observeAllVisitDates().first, <int>[1000, 3000]);

      final ratings = await repository.observeAllVisitDateRatings().first;
      expect(
        <int>[for (final r in ratings) r.visitDate],
        <int>[1000, 3000],
      );
      expect(<int>[for (final r in ratings) r.rating], <int>[2, 5]);
    });
  });

  group('the district vocabulary', () {
    test('only offers values that are actually in the data', () async {
      await repository.insert(restaurant(id: 'a', name: 'First', city: 'Barcelona'));
      await repository.insert(restaurant(id: 'b', name: 'Second', city: 'Girona'));
      await repository.insert(restaurant(id: 'c', name: 'Third'));

      expect(await repository.observeCities().first, <String>[
        'Barcelona',
        'Girona',
      ]);
      expect(await repository.observeRegions().first, isEmpty);
    });
  });
}
