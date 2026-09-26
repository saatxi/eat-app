import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/list/restaurant_list_controller.dart';
import 'package:eatapp/features/list/restaurant_ui_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';

/// The controller's pull-to-refresh path: `refresh()` has to actually re-run the
/// query and then complete, since the gesture's spinner waits on it.
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late RestaurantListController controller;

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    controller = RestaurantListController(
      repository: repository,
      preferences: UserPreferencesRepository(),
      searchDebounce: const Duration(milliseconds: 5),
    );
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  /// Waits for a stream-driven condition rather than guessing at event-loop
  /// turns, the same way the list controller's own tests do.
  Future<void> waitFor(bool Function() condition, {String? description}) async {
    final Stopwatch watch = Stopwatch()..start();
    while (!condition()) {
      if (watch.elapsed > const Duration(seconds: 5)) {
        fail('timed out waiting for ${description ?? 'condition'}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  List<String> ids() => <String>[
    for (final RestaurantUiModel row in controller.state.restaurants) row.id,
  ];

  test('re-runs the query and keeps the rows on screen', () async {
    await repository.insert(restaurant(id: 'a', name: 'A'));
    await waitFor(() => !controller.state.isInitialLoad, description: 'load');

    await controller.refresh();

    expect(ids(), <String>['a']);
  });

  test('picks up a row added behind it, because it runs the query again', () async {
    await waitFor(() => !controller.state.isInitialLoad, description: 'load');
    await repository.insert(restaurant(id: 'a', name: 'A'));

    await controller.refresh();

    expect(ids(), <String>['a']);
  });

  test('completes even when there is nothing to show', () async {
    await waitFor(() => !controller.state.isInitialLoad, description: 'load');

    await controller.refresh();

    expect(controller.state.restaurants, isEmpty);
  });
}
