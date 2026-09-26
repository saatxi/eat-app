import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/detail/restaurant_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

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

  Widget host(Widget screen) => AppScope(
    restaurants: repository,
    preferences: preferences,
    photoPicker: FakePhotoPicker(),
    child: MaterialApp(
      theme: AppTheme.of(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: screen,
    ),
  );

  /// Pumped by hand rather than with `pumpAndSettle`: the loading skeleton
  /// shimmers on a repeating animation, so the tree never reaches a quiet frame
  /// while it is on screen.
  Future<void> pump(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Tears the tree down while the harness is still pumping: cancelling a drift
  /// query stream schedules a deferred-cleanup timer that has to be flushed
  /// before the test ends. See `test/widget_test.dart`.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('logging a visit is the visits section action, not a FAB', (
    WidgetTester tester,
  ) async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    final List<String> logged = <String>[];

    await tester.pumpWidget(
      host(
        RestaurantDetailScreen(restaurantId: 'a', onLogVisit: logged.add),
      ),
    );
    await pump(tester);

    // A floating button sat over the visit cards it is about, hiding them while
    // the page scrolled; the action now belongs to the section it fills.
    expect(find.byType(FloatingActionButton), findsNothing);

    final Finder logVisit = find.widgetWithText(TextButton, 'Log a visit');
    expect(logVisit, findsOneWidget);

    // The visits section is below the fold of the test's viewport.
    await tester.ensureVisible(logVisit);
    await tester.tap(logVisit);
    await tester.pump();

    expect(logged, <String>['a']);

    await disposeApp(tester);
  });
}
