import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/app_version.dart';
import 'package:eatapp/core/l10n/app_language.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/core/theme/app_theme_mode.dart';
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

  /// Null [appVersion] is what a bare widget test has: no platform to ask, so
  /// the About section is absent.
  Widget host({AppVersion? appVersion}) => AppScope(
    restaurants: repository,
    preferences: preferences,
    photoPicker: FakePhotoPicker(),
    appVersion: appVersion,
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

  testWidgets('picking a theme mode stores it', (WidgetTester tester) async {
    await tester.pumpWidget(host());

    expect(preferences.current.themeMode, AppThemeMode.fallback);

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(preferences.current.themeMode, AppThemeMode.dark);
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

  testWidgets('the About section names the version', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(appVersion: const AppVersion('1.2.0')));

    // About sits under the data actions, so the lazy list has to be scrolled
    // down to it before the row exists to be read.
    final Finder version = find.text('Version 1.2.0');
    await tester.scrollUntilVisible(version, 200);
    await tester.ensureVisible(version);
    await tester.pumpAndSettle();

    expect(version, findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('and leaves the build detail out of it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(appVersion: const AppVersion('1.2.0-3-g559a7d4-dirty')),
    );

    final Finder version = find.text('Version 1.2.0');
    await tester.scrollUntilVisible(version, 200);
    await tester.ensureVisible(version);
    await tester.pumpAndSettle();

    expect(version, findsOneWidget);
  });

  testWidgets('there is no About section without a version to name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host());

    // Scrolled to the bottom, where the section would be: the list builds what
    // is near the viewport, so its absence there is worth asserting.
    final Finder deleteTile = find.text('Delete all restaurants');
    await tester.scrollUntilVisible(deleteTile, 200);
    await tester.ensureVisible(deleteTile);
    await tester.pumpAndSettle();

    expect(find.text('About'), findsNothing);
  });
}
