import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/detail/restaurant_detail_screen.dart';
import 'package:eatapp/features/list/restaurant_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

/// The app under a large system text size.
///
/// The editorial type scale is deliberately generous, which is exactly what
/// makes it easy to overflow a row, a chip or an app bar once a user doubles
/// it. Nothing here asserts a *layout* — a render overflow is reported as a
/// framework error, so simply laying the screens out at scale is the assertion,
/// and a regression fails the test on the error rather than on a golden.
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late UserPreferencesRepository preferences;

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
  });

  tearDown(() => db.close());

  Widget host(Widget screen, {required double scale}) => AppScope(
    restaurants: repository,
    preferences: preferences,
    photoPicker: FakePhotoPicker(),
    child: MaterialApp(
      theme: AppTheme.of(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: screen,
        ),
      ),
    ),
  );

  /// A restaurant with every optional field filled in, so the tallest row and
  /// the busiest detail screen are what get scaled.
  Future<void> seed() async {
    await repository.insert(
      restaurant(
        id: 'a',
        name: 'Cal Ferran',
        cuisineType: 'catalan',
        streetAddress: 'Carrer de la Marina 123, baixos',
        city: 'Barcelona',
        region: 'Catalunya',
        country: 'Espanya',
        priceRange: 5,
      ),
      tags: <String>['Terraza', 'Para grupos'],
    );
    await repository.saveSingleVisit(
      restaurantId: 'a',
      visited: true,
      rating: 4,
      notes: 'Demanar la burrata i seure a la terrassa.',
    );
  }

  /// Pumped by hand rather than with `pumpAndSettle`: the initial-load skeletons
  /// pulse forever, so the tree never goes quiet while they are on screen.
  Future<void> pump(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Tears the tree down while the harness is still pumping.
  ///
  /// Cancelling a drift query stream schedules a deferred-cleanup timer, so the
  /// tree has to come down and one more frame be pumped before the test ends —
  /// otherwise the harness fails the test on a timer the widget tree was never
  /// given the chance to flush. See `test/widget_test.dart`.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  for (final double scale in <double>[1.3, 2.0]) {
    testWidgets('the list lays out at ${scale}x text', (
      WidgetTester tester,
    ) async {
      await seed();
      await tester.pumpWidget(
        host(const RestaurantListScreen(), scale: scale),
      );
      await pump(tester);

      expect(find.text('Cal Ferran'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('the detail lays out at ${scale}x text', (
      WidgetTester tester,
    ) async {
      await seed();
      await tester.pumpWidget(
        host(const RestaurantDetailScreen(restaurantId: 'a'), scale: scale),
      );
      await pump(tester);

      expect(find.text('Cal Ferran'), findsWidgets);

      await disposeApp(tester);
    });

    testWidgets('the empty state lays out at ${scale}x text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(const RestaurantListScreen(), scale: scale),
      );
      await pump(tester);

      expect(find.text('No restaurants yet'), findsOneWidget);

      await disposeApp(tester);
    });
  }
}
