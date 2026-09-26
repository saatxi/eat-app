import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/detail/detail_state.dart';
import 'package:eatapp/features/detail/restaurant_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';

/// Waits for a stream-driven condition rather than guessing how many event-loop
/// turns it needs — the restaurant, tag, visit and photo subscriptions all
/// resolve on their own schedule.
Future<void> waitFor(
  bool Function() condition, {
  required String description,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) {
      fail('timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late UserPreferencesRepository preferences;
  late List<RestaurantDetailController> controllers;

  RestaurantDetailController buildController(String restaurantId) {
    final RestaurantDetailController controller = RestaurantDetailController(
      repository: repository,
      preferences: preferences,
      restaurantId: restaurantId,
    );
    controllers.add(controller);
    return controller;
  }

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
    controllers = <RestaurantDetailController>[];
  });

  tearDown(() async {
    for (final RestaurantDetailController controller in controllers) {
      controller.dispose();
    }
    await db.close();
  });

  /// The loaded state, or null while it is still loading or not found — safe to
  /// call from inside a [waitFor] condition, unlike a throwing cast.
  DetailLoaded? tryLoaded(RestaurantDetailController controller) {
    final DetailState state = controller.state;
    return state is DetailLoaded ? state : null;
  }

  DetailLoaded loadedOf(RestaurantDetailController controller) {
    final DetailLoaded? loaded = tryLoaded(controller);
    expect(loaded, isNotNull, reason: 'expected a loaded state');
    return loaded!;
  }

  test('reports the initial load until the database has answered', () async {
    final RestaurantDetailController controller = buildController('ghost');

    expect(controller.state, isA<DetailLoading>());

    await waitFor(
      () => controller.state is! DetailLoading,
      description: 'the first database emission',
    );
    expect(controller.state, isA<DetailNotFound>());
  });

  test('folds the restaurant, its tags and its favourite state', () async {
    await repository.insert(
      restaurant(id: 'a', name: 'Cal Ferran', cuisineType: 'mediterranean'),
      tags: <String>['Terraza', 'Grupos'],
    );
    await preferences.toggleFavorite('a');

    final RestaurantDetailController controller = buildController('a');
    await waitFor(
      () => tryLoaded(controller)?.restaurant.tags.length == 2,
      description: 'the loaded restaurant and its tags',
    );

    final DetailLoaded loaded = loadedOf(controller);
    expect(loaded.restaurant.name, 'Cal Ferran');
    expect(loaded.restaurant.isFavorite, isTrue);
    expect(
      loaded.restaurant.tags,
      unorderedEquals(<String>['Terraza', 'Grupos']),
    );
  });

  test('turns into not-found once the restaurant is gone', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));

    final RestaurantDetailController controller = buildController('a');
    await waitFor(
      () => tryLoaded(controller) != null,
      description: 'the loaded restaurant',
    );

    await repository.delete('a');
    await waitFor(
      () => controller.state is DetailNotFound,
      description: 'the deleted restaurant to disappear',
    );
  });

  test('lists visits newest first and drops a blank note', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await repository.addVisit(
      restaurantId: 'a',
      visitDate: 1000,
      rating: 3,
      notes: 'Abans',
    );
    await repository.addVisit(
      restaurantId: 'a',
      visitDate: 2000,
      rating: 5,
      notes: '   ',
    );

    final RestaurantDetailController controller = buildController('a');
    await waitFor(
      () => tryLoaded(controller)?.visits.length == 2,
      description: 'both visits',
    );

    final List<VisitUiModel> visits = loadedOf(controller).visits;
    expect(visits.first.visitDate, 2000);
    expect(visits.first.notes, isNull, reason: 'a blank note is not a note');
    expect(visits.last.notes, 'Abans');
  });

  test('a single visit has no trend; two build one oldest-first', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await repository.addVisit(restaurantId: 'a', visitDate: 2000, rating: 5);

    final RestaurantDetailController controller = buildController('a');
    await waitFor(
      () => tryLoaded(controller)?.visits.isNotEmpty ?? false,
      description: 'the first visit',
    );
    expect(loadedOf(controller).ratingTrend, isEmpty);

    await repository.addVisit(restaurantId: 'a', visitDate: 1000, rating: 2);
    await waitFor(
      () => tryLoaded(controller)?.ratingTrend.length == 2,
      description: 'the trend',
    );

    final List<RatingPoint> trend = loadedOf(controller).ratingTrend;
    expect(
      <int>[for (final RatingPoint point in trend) point.visitDate],
      <int>[1000, 2000],
      reason: 'a trend line reads chronologically, unlike the timeline',
    );
  });

  test("folds a visit's photos into its card", () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await repository.addVisit(
      restaurantId: 'a',
      visitDate: 1000,
      rating: 4,
      photoSourcePaths: <String>['/tmp/one.jpg', '/tmp/two.jpg'],
    );

    final RestaurantDetailController controller = buildController('a');
    await waitFor(
      () => tryLoaded(controller)?.visits.first.photoPaths.length == 2,
      description: 'the visit and its photos',
    );

    expect(loadedOf(controller).visits.first.photoPaths, <String>[
      '/tmp/one.jpg',
      '/tmp/two.jpg',
    ]);
  });

  test('reflects a favourite toggled from outside', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));

    final RestaurantDetailController controller = buildController('a');
    await waitFor(
      () => tryLoaded(controller) != null,
      description: 'the loaded restaurant',
    );
    expect(loadedOf(controller).restaurant.isFavorite, isFalse);

    await preferences.toggleFavorite('a');
    await waitFor(
      () => tryLoaded(controller)?.restaurant.isFavorite ?? false,
      description: 'the favourite to be reflected',
    );
  });
}
