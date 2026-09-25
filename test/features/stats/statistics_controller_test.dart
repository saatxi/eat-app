import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/features/stats/monthly_trends.dart';
import 'package:eatapp/features/stats/statistics_controller.dart';
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
  late List<StatisticsController> controllers;

  /// A fixed "now" so the trailing-month window is deterministic.
  final DateTime now = DateTime(2026, 3, 15);

  StatisticsController buildController() {
    final StatisticsController controller = StatisticsController(
      repository: repository,
      clock: () => now,
    );
    controllers.add(controller);
    return controller;
  }

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    controllers = <StatisticsController>[];
  });

  tearDown(() async {
    for (final StatisticsController controller in controllers) {
      controller.dispose();
    }
    await db.close();
  });

  test('an empty database reports zero and leaves the initial load', () async {
    final StatisticsController controller = buildController();

    await waitFor(
      () => !controller.state.isInitialLoad,
      description: 'the first database emission',
    );
    expect(controller.state.totalCount, 0);
    expect(controller.state.wantToTryCount, 0);
    expect(controller.state.averageRating, isNull);
  });

  test('splits the total into visited and want-to-try', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await repository.insert(restaurant(id: 'b', name: 'Kebab House'));
    await repository.addVisit(restaurantId: 'a', visitDate: 1, rating: 4);

    final StatisticsController controller = buildController();
    await waitFor(
      () => controller.state.totalCount == 2 && controller.state.visitedCount == 1,
      description: 'both restaurants and the one visit',
    );

    expect(controller.state.wantToTryCount, 1);
    expect(controller.state.averageRating, 4);
  });

  test('counts cuisines, price bands and tags', () async {
    await repository.insert(
      restaurant(id: 'a', name: 'Cal Ferran', cuisineType: 'mediterranean', priceRange: 2),
      tags: <String>['Terraza'],
    );
    await repository.insert(
      restaurant(id: 'b', name: 'Kebab House', cuisineType: 'mediterranean', priceRange: 1),
      tags: <String>['Terraza'],
    );

    final StatisticsController controller = buildController();
    await waitFor(
      () => controller.state.cuisineCounts.isNotEmpty,
      description: 'the cuisine counts',
    );

    expect(controller.state.cuisineCounts.single.cuisineType, 'mediterranean');
    expect(controller.state.cuisineCounts.single.count, 2);
    expect(controller.state.tagCounts.single.name, 'Terraza');
    expect(controller.state.tagCounts.single.count, 2);
    expect(controller.state.priceRangeCounts, hasLength(2));
  });

  test('buckets visits into the trailing months, oldest first', () async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await repository.addVisit(
      restaurantId: 'a',
      visitDate: DateTime(2026, 3, 2).millisecondsSinceEpoch,
      rating: 4,
    );
    await repository.addVisit(
      restaurantId: 'a',
      visitDate: DateTime(2026, 1, 10).millisecondsSinceEpoch,
      rating: 2,
    );

    final StatisticsController controller = buildController();
    await waitFor(
      () => controller.state.monthlyVisitCounts.any(
        (MonthlyVisitCount month) => month.count > 0,
      ),
      description: 'the bucketed visits',
    );

    final List<MonthlyVisitCount> months = controller.state.monthlyVisitCounts;
    expect(months, hasLength(visitTrendMonths));
    expect(months.last.monthKey, '2026-03');
    expect(months.last.count, 1);
    expect(
      months.singleWhere((MonthlyVisitCount m) => m.monthKey == '2026-01').count,
      1,
    );
    expect(
      months.singleWhere((MonthlyVisitCount m) => m.monthKey == '2026-02').count,
      0,
    );
  });
}
