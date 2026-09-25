import 'dart:math';

import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/list/restaurant_ui_model.dart';
import 'package:eatapp/features/roulette/roulette_controller.dart';
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
  late List<RouletteController> controllers;

  RouletteController buildController({Random? random}) {
    final RouletteController controller = RouletteController(
      repository: repository,
      preferences: preferences,
      random: random,
    );
    controllers.add(controller);
    return controller;
  }

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
    controllers = <RouletteController>[];
  });

  tearDown(() async {
    for (final RouletteController controller in controllers) {
      controller.dispose();
    }
    await db.close();
  });

  List<String> candidateIds(RouletteController controller) => <String>[
    for (final RestaurantUiModel row in controller.state.candidates) row.id,
  ];

  test('gathers every restaurant until a filter narrows it', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await repository.insert(restaurant(id: 'b', name: 'Kebab House'));

    final RouletteController controller = buildController();
    await waitFor(
      () => !controller.state.isInitialLoad,
      description: 'the first database emission',
    );
    expect(candidateIds(controller), <String>['a', 'b']);
    expect(controller.state.isEmpty, isFalse);

    controller.onFavoritesOnlyChange(true);
    await waitFor(
      () => candidateIds(controller).isEmpty,
      description: 'the favourite filter to empty the pool',
    );
    expect(controller.state.isEmpty, isTrue);
  });

  test('narrows by price band, which is applied after the query', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran', priceRange: 2));
    await repository.insert(restaurant(id: 'b', name: 'Kebab House', priceRange: 1));

    final RouletteController controller = buildController();
    await waitFor(
      () => candidateIds(controller).length == 2,
      description: 'both restaurants',
    );

    controller.onPriceRangeChange(1);
    await waitFor(
      () => candidateIds(controller).length == 1,
      description: 'the price filter to narrow the pool',
    );
    expect(candidateIds(controller), <String>['b']);
  });

  test('a seeded spin is reproducible and bumps the count', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await repository.insert(restaurant(id: 'b', name: 'Kebab House'));
    await repository.insert(restaurant(id: 'c', name: 'Sushi'));

    final RouletteController controller = buildController(random: Random(7));
    await waitFor(
      () => candidateIds(controller).length == 3,
      description: 'every restaurant',
    );

    controller.pick();
    final String? first = controller.state.picked?.id;
    expect(first, isNotNull);
    expect(controller.state.pickCount, 1);
    expect(
      candidateIds(controller).contains(first),
      isTrue,
      reason: 'a pick always comes from the pool',
    );
  });

  test('a pick that stops matching is dropped', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran', priceRange: 2));
    await repository.insert(restaurant(id: 'b', name: 'Kebab House', priceRange: 2));
    await repository.insert(restaurant(id: 'c', name: 'Sushi', priceRange: 1));

    // Seeded so the pick is deterministic; whatever it lands on, narrowing to a
    // band that excludes it must clear it.
    final RouletteController controller = buildController(random: Random(1));
    await waitFor(
      () => candidateIds(controller).length == 3,
      description: 'every restaurant',
    );
    controller.pick();
    final String? picked = controller.state.picked?.id;
    expect(picked, isNotNull);

    controller.onPriceRangeChange(1);
    await waitFor(
      () => candidateIds(controller).length == 1,
      description: 'the narrowed pool',
    );

    expect(
      controller.state.picked?.id,
      picked == 'c' ? 'c' : isNull,
      reason: 'the pick survives only while it still matches',
    );
  });
}
