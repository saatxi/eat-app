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

/// The filter panel's own clear action, driven through the screen: the chips
/// each toggle themselves off, and clearing a stack of them one chip at a time
/// is exactly what the panel's action exists to avoid.
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
  /// pulse on a repeating animation, and the frames here are only long enough to
  /// cover the panel's own 200ms fold and the menus' open/close.
  Future<void> pump(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Tears the tree down while the harness is still pumping, so drift's
  /// deferred-cleanup timer is flushed. See `test/widget_test.dart`.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// The panel's clear action, which is a `TextButton` like the empty state's.
  Finder clearAction() => find.widgetWithText(TextButton, 'Clear filters');

  testWidgets('the panel clears every filter at once', (
    WidgetTester tester,
  ) async {
    await repository.insert(
      restaurant(id: 'a', name: 'Kebab', cuisineType: 'turkish'),
    );
    await repository.insert(
      restaurant(id: 'b', name: 'Sushi', cuisineType: 'japanese'),
    );
    await tester.pumpWidget(host(const RestaurantListScreen()));
    await pump(tester);

    expect(find.text('Kebab'), findsOneWidget);
    expect(find.text('Sushi'), findsOneWidget);

    // The panel starts folded, and with nothing to clear it has no action.
    await tester.tap(find.text('Filters'));
    await pump(tester);
    expect(clearAction(), findsNothing);

    // Narrow the list with one of the chips.
    await tester.tap(find.text('Cuisine'));
    await pump(tester);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Japanese'));
    await pump(tester);

    expect(find.text('Kebab'), findsNothing);
    expect(clearAction(), findsOneWidget);

    // One tap instead of reopening the chip's menu to unpick it.
    await tester.tap(clearAction());
    await pump(tester);

    expect(find.text('Kebab'), findsOneWidget);
    expect(clearAction(), findsNothing);

    await disposeApp(tester);
  });
}
