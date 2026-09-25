import 'package:eatapp/data/db/app_database.dart';
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

  Future<void> seedVisit() => db.visitDao.insertVisit(
    visit(id: 'v1', restaurantId: 'a', visitDate: 1000, rating: 4),
  );

  test('orders a restaurant\'s photos by position', () async {
    await seedRestaurants();
    await db.photoDao.insertPhoto(
      photo(id: 'p2', restaurantId: 'a', path: '/photos/2.jpg', position: 1),
    );
    await db.photoDao.insertPhoto(
      photo(id: 'p1', restaurantId: 'a', path: '/photos/1.jpg'),
    );
    await db.photoDao.insertPhoto(
      photo(id: 'other', restaurantId: 'b', path: '/photos/other.jpg'),
    );

    expect(
      (await db.photoDao.observePhotosForRestaurant('a').first)
          .map((Photo p) => p.id)
          .toList(),
      <String>['p1', 'p2'],
    );
  });

  test('orders a visit\'s photos by position', () async {
    await seedRestaurants();
    await seedVisit();
    await db.photoDao.insertPhoto(
      photo(id: 'p2', visitId: 'v1', path: '/photos/2.jpg', position: 1),
    );
    await db.photoDao.insertPhoto(
      photo(id: 'p1', visitId: 'v1', path: '/photos/1.jpg'),
    );

    expect(
      (await db.photoDao.observePhotosForVisit('v1').first)
          .map((Photo p) => p.id)
          .toList(),
      <String>['p1', 'p2'],
    );
  });

  test('getFirstPhotoForRestaurant picks the lowest position', () async {
    await seedRestaurants();
    expect(await db.photoDao.getFirstPhotoForRestaurant('a'), isNull);

    await db.photoDao.insertPhoto(
      photo(id: 'p2', restaurantId: 'a', path: '/photos/2.jpg', position: 5),
    );
    await db.photoDao.insertPhoto(
      photo(id: 'p1', restaurantId: 'a', path: '/photos/1.jpg', position: 2),
    );

    expect((await db.photoDao.getFirstPhotoForRestaurant('a'))!.id, 'p1');
  });

  test('getById returns the row or null', () async {
    await seedRestaurants();
    await db.photoDao.insertPhoto(
      photo(id: 'p1', restaurantId: 'a', path: '/photos/1.jpg'),
    );

    expect((await db.photoDao.getById('p1'))!.path, '/photos/1.jpg');
    expect(await db.photoDao.getById('missing'), isNull);
  });

  test('getMaxPositionForRestaurant is -1 with none, then the highest', () async {
    await seedRestaurants();
    expect(await db.photoDao.getMaxPositionForRestaurant('a'), -1);

    await db.photoDao.insertPhoto(
      photo(id: 'p1', restaurantId: 'a', path: '/photos/1.jpg'),
    );
    await db.photoDao.insertPhoto(
      photo(id: 'p2', restaurantId: 'a', path: '/photos/2.jpg', position: 4),
    );

    expect(await db.photoDao.getMaxPositionForRestaurant('a'), 4);
  });

  test('deletePhoto removes one row', () async {
    await seedRestaurants();
    await db.photoDao.insertPhoto(
      photo(id: 'p1', restaurantId: 'a', path: '/photos/1.jpg'),
    );
    await db.photoDao.insertPhoto(
      photo(id: 'p2', restaurantId: 'a', path: '/photos/2.jpg', position: 1),
    );

    await db.photoDao.deletePhoto('p1');

    expect(
      (await db.photoDao.observePhotosForRestaurant('a').first)
          .map((Photo p) => p.id)
          .toList(),
      <String>['p2'],
    );
  });

  test('deleteAllPhotosForRestaurant leaves the visit photos alone', () async {
    await seedRestaurants();
    await seedVisit();
    await db.photoDao.insertPhoto(
      photo(id: 'p1', restaurantId: 'a', path: '/photos/1.jpg'),
    );
    await db.photoDao.insertPhoto(
      photo(id: 'p2', visitId: 'v1', path: '/photos/visit.jpg'),
    );

    await db.photoDao.deleteAllPhotosForRestaurant('a');

    expect(await db.photoDao.observePhotosForRestaurant('a').first, isEmpty);
    expect(await db.photoDao.observePhotosForVisit('v1').first, hasLength(1));
  });

  test('deleting a restaurant cascades to its photos', () async {
    await seedRestaurants();
    await seedVisit();
    await db.photoDao.insertPhoto(
      photo(id: 'p1', restaurantId: 'a', path: '/photos/1.jpg'),
    );
    await db.photoDao.insertPhoto(
      photo(id: 'p2', restaurantId: 'b', path: '/photos/other.jpg'),
    );
    // A visit photo goes with the visit, which goes with the restaurant.
    await db.photoDao.insertPhoto(
      photo(id: 'p3', visitId: 'v1', path: '/photos/visit.jpg'),
    );

    await db.restaurantDao.deleteRestaurant('a');

    expect(await db.photoDao.getById('p1'), isNull);
    expect(await db.photoDao.getById('p3'), isNull);
    expect(await db.photoDao.getById('p2'), isNotNull);
  });

  test('deleting a visit cascades to that visit\'s photos', () async {
    await seedRestaurants();
    await seedVisit();
    await db.photoDao.insertPhoto(
      photo(id: 'p1', restaurantId: 'a', path: '/photos/1.jpg'),
    );
    await db.photoDao.insertPhoto(
      photo(id: 'p2', visitId: 'v1', path: '/photos/visit.jpg'),
    );

    await db.visitDao.deleteVisit('v1');

    expect(await db.photoDao.getById('p2'), isNull);
    expect(await db.photoDao.getById('p1'), isNotNull);
  });
}
