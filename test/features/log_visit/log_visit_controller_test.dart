import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/features/log_visit/log_visit_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late List<LogVisitController> controllers;

  LogVisitController buildController({
    DateTime? now,
    String restaurantId = 'a',
  }) {
    final LogVisitController controller = LogVisitController(
      repository: repository,
      restaurantId: restaurantId,
      now: now,
    );
    controllers.add(controller);
    return controller;
  }

  setUp(() async {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    controllers = <LogVisitController>[];
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
  });

  tearDown(() async {
    for (final LogVisitController controller in controllers) {
      controller.dispose();
    }
    await db.close();
  });

  test('starts on today, unrated and with no price band', () {
    final DateTime now = DateTime(2026, 3, 4, 12);
    final LogVisitController controller = buildController(now: now);

    expect(controller.state.visitDate, now.millisecondsSinceEpoch);
    expect(controller.state.rating, 0);
    expect(controller.state.priceRange, 0);
  });

  test('clamps a rating and a price band to their scales', () {
    final LogVisitController controller = buildController();

    controller.onRatingChange(9);
    controller.onPriceRangeChange(9);
    expect(controller.state.rating, 5);
    expect(controller.state.priceRange, 6);

    controller.onRatingChange(-1);
    controller.onPriceRangeChange(-1);
    expect(controller.state.rating, 0);
    expect(controller.state.priceRange, 0);
  });

  test('saves a visit, trimming a blank note away', () async {
    final LogVisitController controller = buildController(now: DateTime(2026, 3, 4));
    controller.onRatingChange(4);
    controller.onPriceRangeChange(2);
    controller.onNotesChange('   ');

    await controller.save();

    final List<Visit> visits = await repository.observeVisitsForRestaurant('a').first;
    expect(visits, hasLength(1));
    expect(visits.single.rating, 4);
    expect(visits.single.priceRange, 2);
    expect(visits.single.notes, isNull);
  });

  test('keeps the note it was given', () async {
    final LogVisitController controller = buildController();
    controller.onNotesChange('  Molt bo  ');

    await controller.save();

    final List<Visit> visits = await repository.observeVisitsForRestaurant('a').first;
    expect(visits.single.notes, 'Molt bo');
  });

  test('a second save while one is in flight is ignored', () async {
    final LogVisitController controller = buildController();

    await Future.wait<void>(<Future<void>>[controller.save(), controller.save()]);

    final List<Visit> visits = await repository.observeVisitsForRestaurant('a').first;
    expect(visits, hasLength(1), reason: 'a double tap logs one visit');
  });

  group('photos', () {
    late FakePhotoStorage storage;
    late FakePhotoPicker picker;

    setUp(() {
      storage = FakePhotoStorage();
      picker = FakePhotoPicker();
      repository = RestaurantRepository(db, photoStorage: storage);
    });

    LogVisitController build() {
      final LogVisitController controller = LogVisitController(
        repository: repository,
        restaurantId: 'a',
        photoPicker: picker,
        now: DateTime(2026, 3, 4),
      );
      controllers.add(controller);
      return controller;
    }

    test('a picked photo is carried onto the saved visit', () async {
      picker.nextPath = '/tmp/one.jpg';
      final LogVisitController controller = build();

      await controller.pickPhoto();
      expect(controller.state.photoSourcePaths, <String>['/tmp/one.jpg']);

      await controller.save();

      final List<Visit> visits = await repository
          .observeVisitsForRestaurant('a')
          .first;
      final List<Photo> photos = await repository
          .observePhotosForVisit(visits.single.id)
          .first;
      expect(<String>[for (final Photo photo in photos) photo.path], <String>[
        'stored/one.jpg',
      ]);
    });

    test('a cancelled pick stages nothing', () async {
      picker.nextPath = null;
      final LogVisitController controller = build();

      await controller.pickPhoto();

      expect(controller.state.photoSourcePaths, isEmpty);
    });

    test('removing a staged photo drops just that one', () async {
      picker.nextPath = '/tmp/one.jpg';
      final LogVisitController controller = build();
      await controller.pickPhoto();
      picker.nextPath = '/tmp/two.jpg';
      await controller.pickPhoto();
      expect(controller.state.photoSourcePaths, hasLength(2));

      controller.removePhoto('/tmp/one.jpg');

      expect(controller.state.photoSourcePaths, <String>['/tmp/two.jpg']);
    });
  });
}
