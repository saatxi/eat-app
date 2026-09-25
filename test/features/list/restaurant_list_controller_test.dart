import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/models/restaurant_sort.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/list/restaurant_list_controller.dart';
import 'package:eatapp/features/list/restaurant_ui_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';

/// Waits for a stream- and timer-driven condition instead of guessing how many
/// event-loop turns it needs — the database, the debounce and the four side
/// subscriptions all resolve on their own schedule.
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
  late List<RestaurantListController> controllers;

  /// Every controller built by a test, so each one is disposed exactly once.
  RestaurantListController buildController({
    Duration searchDebounce = const Duration(milliseconds: 5),
  }) {
    final RestaurantListController controller = RestaurantListController(
      repository: repository,
      preferences: preferences,
      searchDebounce: searchDebounce,
    );
    controllers.add(controller);
    return controller;
  }

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
    controllers = <RestaurantListController>[];
  });

  tearDown(() async {
    for (final RestaurantListController controller in controllers) {
      controller.dispose();
    }
    await db.close();
  });

  List<String> idsOf(RestaurantListController controller) => <String>[
    for (final RestaurantUiModel row in controller.state.restaurants) row.id,
  ];

  test('reports the initial load until the database has answered', () async {
    final RestaurantListController controller = buildController();

    expect(controller.state.isInitialLoad, isTrue);
    expect(controller.state.restaurants, isEmpty);

    await waitFor(
      () => !controller.state.isInitialLoad,
      description: 'the first database emission',
    );
    expect(controller.state.restaurants, isEmpty);
  });

  test('lists what the database holds', () async {
    await repository.insert(restaurant(id: 'a', name: 'Kebab'));
    await repository.insert(restaurant(id: 'b', name: 'Sushi'));
    final RestaurantListController controller = buildController();

    await waitFor(
      () => controller.state.restaurants.length == 2,
      description: 'both restaurants',
    );
    expect(idsOf(controller), <String>['a', 'b']);
  });

  test('folds the favourites, the tags and the latest visit into the rows', () async {
    await repository.insert(
      restaurant(id: 'a', name: 'Kebab'),
      tags: <String>['Terraza'],
    );
    await repository.saveSingleVisit(
      restaurantId: 'a',
      visited: true,
      rating: 4,
      notes: 'Bones',
    );
    await preferences.toggleFavorite('a');
    final RestaurantListController controller = buildController();

    await waitFor(
      () =>
          controller.state.restaurants.isNotEmpty &&
          controller.state.restaurants.single.rating == 4,
      description: 'the row with its visit',
    );

    final RestaurantUiModel row = controller.state.restaurants.single;
    expect(row.isFavorite, isTrue);
    expect(row.visited, isTrue);
    expect(row.tags, <String>['Terraza']);
    expect(row.notes, 'Bones');
  });

  test('reacts to a favourite being toggled from somewhere else', () async {
    await repository.insert(restaurant(id: 'a', name: 'Kebab'));
    final RestaurantListController controller = buildController();
    await waitFor(
      () => controller.state.restaurants.length == 1,
      description: 'the restaurant',
    );
    expect(controller.state.restaurants.single.isFavorite, isFalse);

    await preferences.toggleFavorite('a');

    await waitFor(
      () => controller.state.restaurants.single.isFavorite,
      description: 'the favourite',
    );
  });

  test('offers the filter vocabulary the data actually uses', () async {
    await repository.insert(
      restaurant(id: 'a', name: 'Kebab', cuisineType: 'turkish', city: 'Girona'),
    );
    await repository.insert(
      restaurant(id: 'b', name: 'Sushi', cuisineType: 'japanese', city: 'Blanes'),
    );
    final RestaurantListController controller = buildController();

    await waitFor(
      () => controller.state.availableCities.length == 2,
      description: 'both cities',
    );
    // The cuisines query is a plain DISTINCT with no ORDER BY, so the sequence
    // is SQLite's business; the location queries do sort, and are asserted in
    // order.
    expect(
      controller.state.availableCuisines,
      unorderedEquals(<String>['japanese', 'turkish']),
    );
    expect(controller.state.availableCities, <String>['Blanes', 'Girona']);
  });

  group('the filters', () {
    test('are carried into the state, and the order alone is not a filter', () async {
      final RestaurantListController controller = buildController();

      controller.onMinRatingChange(4);
      controller.onCuisineChange('japanese');
      controller.onSortChange(RestaurantSort.rating);

      expect(controller.state.minRating, 4);
      expect(controller.state.cuisineType, 'japanese');
      expect(controller.state.sort, RestaurantSort.rating);
      expect(controller.state.hasActiveFilter, isTrue);

      controller.clearFilters();
      controller.onSortChange(RestaurantSort.rating);
      expect(controller.state.hasActiveFilter, isFalse);
    });

    test('narrow the list down', () async {
      await repository.insert(restaurant(id: 'a', name: 'Kebab', cuisineType: 'turkish'));
      await repository.insert(restaurant(id: 'b', name: 'Sushi', cuisineType: 'japanese'));
      final RestaurantListController controller = buildController();
      await waitFor(
        () => controller.state.restaurants.length == 2,
        description: 'both restaurants',
      );

      controller.onCuisineChange('japanese');

      await waitFor(
        () => controller.state.restaurants.length == 1,
        description: 'the narrowed list',
      );
      expect(idsOf(controller), <String>['b']);
    });

    test('are cleared without touching the chosen order', () async {
      await repository.insert(restaurant(id: 'a', name: 'Kebab', cuisineType: 'turkish'));
      await repository.insert(restaurant(id: 'b', name: 'Sushi', cuisineType: 'japanese'));
      final RestaurantListController controller = buildController();
      await waitFor(
        () => controller.state.restaurants.length == 2,
        description: 'both restaurants',
      );

      controller.onCuisineChange('japanese');
      controller.onSortChange(RestaurantSort.rating);
      await waitFor(
        () => controller.state.restaurants.length == 1,
        description: 'the narrowed list',
      );

      controller.clearFilters();

      await waitFor(
        () => controller.state.restaurants.length == 2,
        description: 'the full list again',
      );
      expect(controller.state.cuisineType, isNull);
      expect(controller.state.hasActiveFilter, isFalse);
      expect(controller.state.sort, RestaurantSort.rating);
    });

    test('notify only when they actually change', () async {
      final RestaurantListController controller = buildController();
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.onMinRatingChange(4);
      expect(notifications, 1);

      controller.onMinRatingChange(4);
      expect(notifications, 1);
    });
  });

  group('the search query', () {
    test('is shown at once while the list waits for the debounce', () async {
      await repository.insert(restaurant(id: 'a', name: 'Kebab'));
      await repository.insert(restaurant(id: 'b', name: 'Sushi'));
      // Long enough that nothing can narrow by accident inside the test.
      final RestaurantListController controller = buildController(
        searchDebounce: const Duration(seconds: 30),
      );
      await waitFor(
        () => controller.state.restaurants.length == 2,
        description: 'both restaurants',
      );

      controller.onSearchQueryChange('kebab');

      expect(controller.state.searchQuery, 'kebab');
      expect(controller.state.hasActiveFilter, isTrue);
      expect(controller.state.restaurants.length, 2);
    });

    test('narrows the list once the debounce has elapsed', () async {
      await repository.insert(restaurant(id: 'a', name: 'Kebab'));
      await repository.insert(restaurant(id: 'b', name: 'Sushi'));
      final RestaurantListController controller = buildController();
      await waitFor(
        () => controller.state.restaurants.length == 2,
        description: 'both restaurants',
      );

      controller.onSearchQueryChange('kebab');

      await waitFor(
        () => controller.state.restaurants.length == 1,
        description: 'the narrowed list',
      );
      expect(idsOf(controller), <String>['a']);
    });

    test('can be typed and cleared before the debounce elapses', () async {
      await repository.insert(restaurant(id: 'a', name: 'Kebab'));
      await repository.insert(restaurant(id: 'b', name: 'Sushi'));
      final RestaurantListController controller = buildController(
        searchDebounce: const Duration(milliseconds: 100),
      );
      await waitFor(
        () => controller.state.restaurants.length == 2,
        description: 'both restaurants',
      );

      controller.onSearchQueryChange('sushi');
      controller.onSearchQueryChange('');

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(controller.state.searchQuery, '');
      expect(idsOf(controller), <String>['a', 'b']);
    });
  });

  test('deletes a restaurant and the row goes with it', () async {
    await repository.insert(restaurant(id: 'a', name: 'Kebab'));
    await repository.insert(restaurant(id: 'b', name: 'Sushi'));
    final RestaurantListController controller = buildController();
    await waitFor(
      () => controller.state.restaurants.length == 2,
      description: 'both restaurants',
    );

    await controller.deleteRestaurant('a');

    await waitFor(
      () => controller.state.restaurants.length == 1,
      description: 'the remaining restaurant',
    );
    expect(idsOf(controller), <String>['b']);
  });

  test('toggling a favourite persists it', () async {
    await repository.insert(restaurant(id: 'a', name: 'Kebab'));
    final RestaurantListController controller = buildController();
    await waitFor(
      () => controller.state.restaurants.length == 1,
      description: 'the restaurant',
    );

    await controller.toggleFavorite('a');

    expect(preferences.isFavorite('a'), isTrue);
    await waitFor(
      () => controller.state.restaurants.single.isFavorite,
      description: 'the favourite on the row',
    );
  });

  test('stops publishing once disposed', () async {
    await repository.insert(restaurant(id: 'a', name: 'Kebab'));
    final RestaurantListController controller = buildController();
    await waitFor(
      () => controller.state.restaurants.length == 1,
      description: 'the restaurant',
    );

    // Registered before the dispose: `addListener` is the one ChangeNotifier
    // entry point that refuses to run on a disposed notifier.
    int notifications = 0;
    controller.addListener(() => notifications++);

    controller.dispose();
    controllers.remove(controller);

    controller.onSearchQueryChange('kebab');
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(notifications, 0);
  });
}
