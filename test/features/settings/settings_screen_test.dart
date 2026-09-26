import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/app_language.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_palette.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late UserPreferencesRepository preferences;

  setUp(() {
    db = AppDatabase.memory();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
  });

  tearDown(() => db.close());

  Widget host() => AppScope(
    restaurants: repository,
    preferences: preferences,
    photoPicker: FakePhotoPicker(),
    child: MaterialApp(
      theme: AppTheme.of(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: SettingsScreen(onViewStatistics: () {}),
    ),
  );

  /// Taps the language selector's anchor and waits for its menu to open. The
  /// anchor is a `ListTile`, so it is found by its drop-down arrow rather than
  /// by its label — the label is the current choice and changes with it.
  Future<void> openLanguageSelector(WidgetTester tester) async {
    await tester.tap(find.widgetWithIcon(ListTile, Icons.arrow_drop_down));
    await tester.pumpAndSettle();
  }

  testWidgets('picking a palette stores it', (WidgetTester tester) async {
    await tester.pumpWidget(host());

    expect(preferences.current.palette, AppPalette.fallback);

    await tester.tap(find.text('Garden'));
    await tester.pump();

    expect(preferences.current.palette, AppPalette.garden);
  });

  testWidgets('the selector offers only the shipped languages, and stores one', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host());

    // Nothing is stored yet, so the anchor shows the language the app resolved
    // to — English, the locale this host pins — and the remaining choices only
    // exist while the menu is open.
    expect(find.widgetWithText(ListTile, 'English'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Spanish'), findsNothing);

    await openLanguageSelector(tester);

    // The shipped languages and nothing else: no "follow the device" row, and
    // no language the app has no translations for.
    expect(find.byType(MenuItemButton), findsNWidgets(3));

    await tester.tap(find.widgetWithText(MenuItemButton, 'Spanish'));
    await tester.pumpAndSettle();

    expect(preferences.current.language, AppLanguage.spanish);
    expect(find.widgetWithText(ListTile, 'Spanish'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Spanish'), findsNothing);
  });

  testWidgets('deleting everything waits for the confirmation', (
    WidgetTester tester,
  ) async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await tester.pumpWidget(host());

    // The list only builds what is on screen, and the data rows sit below the
    // appearance ones. scrollUntilVisible builds the row as it scrolls, but can
    // stop while it is still inside the cache extent but below the fold, so
    // ensureVisible then brings it fully on screen before it is tapped.
    final Finder deleteTile = find.text('Delete all restaurants');
    await tester.scrollUntilVisible(deleteTile, 200);
    await tester.ensureVisible(deleteTile);
    await tester.pumpAndSettle();
    await tester.tap(deleteTile);
    await tester.pumpAndSettle();

    // Cancelling leaves the row alone.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await db.restaurantDao.getAll(), hasLength(1));

    await tester.ensureVisible(deleteTile);
    await tester.pumpAndSettle();
    await tester.tap(deleteTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(await db.restaurantDao.getAll(), isEmpty);
  });
}
