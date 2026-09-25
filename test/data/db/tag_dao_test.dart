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

  group('setTags', () {
    test('creates the tags and links, sorted by name', () async {
      await seedRestaurants();

      await db.tagDao.setTags('a', <String>['Terraza', 'llevar niños']);

      expect(await db.tagDao.observeTagNames('a').first, <String>[
        'llevar niños',
        'Terraza',
      ]);
    });

    test('reuses an existing tag case-insensitively', () async {
      await seedRestaurants();

      await db.tagDao.setTags('a', <String>['Terraza']);
      await db.tagDao.setTags('b', <String>['terraza']);

      // One tag in the vocabulary, its original spelling kept, linked to both.
      expect(await db.tagDao.observeAllTagNames().first, <String>['Terraza']);
      expect(await db.tagDao.observeTagNames('b').first, <String>['Terraza']);
    });

    test('replaces the previous links rather than appending', () async {
      await seedRestaurants();

      await db.tagDao.setTags('a', <String>['uno', 'dos']);
      await db.tagDao.setTags('a', <String>['tres']);

      expect(await db.tagDao.observeTagNames('a').first, <String>['tres']);
      // The orphaned tags stay in the vocabulary, so autocomplete still offers
      // them next time.
      expect(await db.tagDao.observeAllTagNames().first, <String>[
        'dos',
        'tres',
        'uno',
      ]);
    });

    test('de-duplicates case-insensitive duplicates in one call', () async {
      await seedRestaurants();

      await db.tagDao.setTags('a', <String>[
        'Terraza',
        'terraza',
        ' TERRAZA ',
      ]);

      expect(await db.tagDao.observeTagNames('a').first, hasLength(1));
      expect(await db.tagDao.observeAllTagNames().first, hasLength(1));
    });

    test('leaves the other restaurant\'s tags alone', () async {
      await seedRestaurants();

      await db.tagDao.setTags('a', <String>['uno']);
      await db.tagDao.setTags('b', <String>['dos']);

      expect(await db.tagDao.observeTagNames('a').first, <String>['uno']);
      expect(await db.tagDao.observeTagNames('b').first, <String>['dos']);
    });

    test('an empty list simply clears the restaurant\'s tags', () async {
      await seedRestaurants();
      await db.tagDao.setTags('a', <String>['uno']);

      await db.tagDao.setTags('a', <String>[]);

      expect(await db.tagDao.observeTagNames('a').first, isEmpty);
      expect(await db.tagDao.observeAllTagNames().first, <String>['uno']);
    });
  });

  test('insertTagIfAbsent reports the case-insensitive conflict', () async {
    expect(
      await db.tagDao.insertTagIfAbsent(tag(id: 't1', name: 'Terraza')),
      isNotNull,
    );
    expect(
      await db.tagDao.insertTagIfAbsent(tag(id: 't2', name: 'terraza')),
      isNull,
    );
  });

  test('groups the restaurant/tag links by restaurant', () async {
    await seedRestaurants();

    await db.tagDao.setTags('a', <String>['uno']);
    await db.tagDao.setTags('b', <String>['dos']);

    final List<RestaurantTagName> links =
        await db.tagDao.observeAllRestaurantTagLinks().first;
    expect(
      <String>{for (final RestaurantTagName link in links) '${link.restaurantId}:${link.name}'},
      <String>{'a:uno', 'b:dos'},
    );
  });

  test('ranks tags by how many restaurants carry them', () async {
    await seedRestaurants();

    await db.tagDao.setTags('a', <String>['popular', 'rare']);
    await db.tagDao.setTags('b', <String>['popular']);

    final List<TagCount> counts = await db.tagDao.observeTagCounts().first;
    expect(counts.first.name, 'popular');
    expect(counts.first.count, 2);
    expect(counts.last.name, 'rare');
    expect(counts.last.count, 1);
  });

  test('deleting a restaurant drops its links but keeps the vocabulary', () async {
    await seedRestaurants();
    await db.tagDao.setTags('a', <String>['uno']);

    await db.restaurantDao.deleteRestaurant('a');

    expect(await db.tagDao.observeAllRestaurantTagLinks().first, isEmpty);
    expect(await db.tagDao.observeAllTagNames().first, <String>['uno']);
  });

  test('deleteAllTags clears the vocabulary and the links', () async {
    await seedRestaurants();
    await db.tagDao.setTags('a', <String>['uno']);

    await db.tagDao.deleteAllTags();

    expect(await db.tagDao.observeAllTagNames().first, isEmpty);
    expect(await db.tagDao.observeAllRestaurantTagLinks().first, isEmpty);
  });
}
