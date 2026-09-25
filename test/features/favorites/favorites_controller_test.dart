import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/list/restaurant_list_controller.dart';
import 'package:eatapp/features/list/restaurant_ui_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';

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

  /// The same controller the list uses, narrowed to favourites.
  RestaurantListController buildController() {
    final RestaurantListController controller = RestaurantListController(
      repository: repository,
      preferences: preferences,
      favouritesOnly: true,
      searchDebounce: const Duration(milliseconds: 5),
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

  test('shows only the hearted restaurants', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await repository.insert(restaurant(id: 'b', name: 'Kebab House'));
    await preferences.toggleFavorite('b');

    final RestaurantListController controller = buildController();
    await waitFor(
      () => !controller.state.isInitialLoad,
      description: 'the first database emission',
    );

    expect(idsOf(controller), <String>['b']);
  });

  test('follows a favourite added and removed from anywhere', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));

    final RestaurantListController controller = buildController();
    await waitFor(
      () => !controller.state.isInitialLoad,
      description: 'the first database emission',
    );
    expect(idsOf(controller), isEmpty);

    await preferences.toggleFavorite('a');
    await waitFor(
      () => idsOf(controller).isNotEmpty,
      description: 'the new favourite',
    );
    expect(idsOf(controller), <String>['a']);

    await preferences.toggleFavorite('a');
    await waitFor(
      () => idsOf(controller).isEmpty,
      description: 'the removed favourite',
    );
  });

  test('the search still narrows the favourites down', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await repository.insert(restaurant(id: 'b', name: 'Kebab House'));
    await preferences.toggleFavorite('a');
    await preferences.toggleFavorite('b');

    final RestaurantListController controller = buildController();
    await waitFor(
      () => idsOf(controller).length == 2,
      description: 'both favourites',
    );

    controller.onSearchQueryChange('kebab');
    await waitFor(
      () => idsOf(controller).length == 1,
      description: 'the search to narrow the favourites',
    );
    expect(idsOf(controller), <String>['b']);
  });
}
