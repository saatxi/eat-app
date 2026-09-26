import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/stats/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

/// What the statistics screen draws for a given set of data — including the two
/// sections that are *conditional*, since those are exactly the ones a silent
/// regression would drop without any test noticing.
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
  });

  tearDown(() => db.close());

  Future<void> pumpStatistics(WidgetTester tester) async {
    // A tall surface, so every section is laid out: the screen is a lazy
    // `ListView`, and the sections below the fold would otherwise not be built
    // at all and a `find.text` for one of them would report a false absence.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        restaurants: repository,
        preferences: UserPreferencesRepository(),
        photoPicker: FakePhotoPicker(),
        child: MaterialApp(
          theme: AppTheme.of(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const StatisticsScreen(),
        ),
      ),
    );
    // The database answers on the real event loop, so `runAsync` is what lets
    // the first emission land — pumping alone would leave the spinner up.
    // `pumpAndSettle` is not an option either: that spinner never settles.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('shows the empty state with nothing collected', (
    WidgetTester tester,
  ) async {
    await pumpStatistics(tester);

    expect(find.text('Nothing to show yet'), findsOneWidget);
    expect(find.text('Cuisines'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('summarises the collection once there is data', (
    WidgetTester tester,
  ) async {
    await repository.insert(
      restaurant(
        id: 'a',
        name: 'Cal Ferran',
        cuisineType: 'catalan',
        city: 'Barcelona',
        priceRange: 3,
      ),
      tags: <String>['Terraza'],
    );
    await repository.insert(restaurant(id: 'b', name: 'B', cuisineType: 'italian'));
    await repository.insert(restaurant(id: 'c', name: 'C', cuisineType: 'italian'));

    // Two visited months, so the rating trend has a slope to draw; the second
    // is inside the six-month window either way.
    final DateTime now = DateTime.now();
    await repository.addVisit(
      restaurantId: 'a',
      visitDate: now.millisecondsSinceEpoch,
      rating: 4,
    );
    await repository.addVisit(
      restaurantId: 'a',
      visitDate: now.subtract(const Duration(days: 40)).millisecondsSinceEpoch,
      rating: 2,
    );

    await pumpStatistics(tester);

    expect(find.text('3'), findsWidgets, reason: 'the headline total');
    expect(find.text('Visited'), findsOneWidget);
    expect(find.text('Want to try'), findsOneWidget);
    expect(find.text('Avg. rating'), findsOneWidget);

    expect(find.text('Cuisines'), findsOneWidget);
    expect(find.text('Price range'), findsOneWidget);
    expect(find.text('Visits per month'), findsOneWidget);
    expect(find.text('Average rating over time'), findsOneWidget);
    expect(find.text('Top tags'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('drops the sections with nothing behind them', (
    WidgetTester tester,
  ) async {
    // One restaurant, never visited and with no tags: the total tile and the
    // cuisine/price breakdowns have something to say, the monthly bars, the
    // rating trend and the top tags do not.
    await repository.insert(
      restaurant(id: 'a', name: 'Cal Ferran', cuisineType: 'catalan', priceRange: 3),
    );

    await pumpStatistics(tester);

    expect(find.text('Cuisines'), findsOneWidget);
    expect(find.text('Price range'), findsOneWidget);
    expect(find.text('Visits per month'), findsNothing);
    expect(find.text('Average rating over time'), findsNothing);
    expect(find.text('Top tags'), findsNothing);

    await disposeApp(tester);
  });
}
