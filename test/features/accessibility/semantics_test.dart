import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/list/restaurant_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

/// The screen-reader contract the screens add on top of the framework's own:
/// the empty states announce their point as a heading, and a filter that
/// narrows the list announces the new count rather than changing it silently.
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

  /// Pumped by hand rather than with `pumpAndSettle`: the initial-load skeletons
  /// pulse forever, so the tree never goes quiet while they are on screen.
  Future<void> pump(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// See `test/widget_test.dart` for why the tree has to be taken down while the
  /// harness is still pumping.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder liveRegions() => find.byWidgetPredicate(
    (Widget widget) => widget is Semantics && widget.properties.liveRegion == true,
  );

  testWidgets('the empty state announces its title as a heading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(const RestaurantListScreen()));
    await pump(tester);

    final Semantics semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.text('No restaurants yet'),
            matching: find.byType(Semantics),
          )
          .first,
    );

    expect(semantics.properties.header, isTrue);

    await disposeApp(tester);
  });

  testWidgets('narrowing the list announces the new count', (
    WidgetTester tester,
  ) async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await tester.pumpWidget(host(const RestaurantListScreen()));
    await pump(tester);

    // Nothing is filtered yet, so there is no count to announce.
    expect(liveRegions(), findsNothing);

    await tester.enterText(find.byType(TextField), 'ferran');
    // Past the query debounce, so the narrowed result set has landed.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 50));

    expect(liveRegions(), findsOneWidget);

    await disposeApp(tester);
  });
}
