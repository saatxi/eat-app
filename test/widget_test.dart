import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/palettes/verd_palette.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late RestaurantRepository repository;

  setUp(() {
    database = AppDatabase.memory();
    repository = RestaurantRepository(database);
  });

  tearDown(() => database.close());

  /// Pumps the app and lets the database's first emission land.
  ///
  /// Deliberately not `pumpAndSettle`: the initial-load skeletons pulse on a
  /// repeating animation, so the tree never reaches a quiet frame while they are
  /// on screen. A few timed pumps are enough for the in-memory stream to emit.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      EatApp(repository: repository, preferences: UserPreferencesRepository()),
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Tears the app down while the harness is still pumping.
  ///
  /// Cancelling a drift query stream schedules a deferred-cleanup timer, so the
  /// tree has to come down and one more frame be pumped before the test ends —
  /// otherwise the harness fails the test on a timer the widget tree was never
  /// given the chance to flush.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('the app opens on the restaurant list', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('My Restaurants'), findsOneWidget);
    expect(find.text('No restaurants yet'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('the bottom navigation switches tabs', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );

    await disposeApp(tester);
  });

  testWidgets('builds on the stored mode', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme!.colorScheme.primary, verdTones.primary.t40);

    await disposeApp(tester);
  });

  testWidgets('a fresh install follows the device language', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, isNull, reason: 'a fresh install follows the device');
    expect(app.supportedLocales, AppLocalizations.supportedLocales);

    await disposeApp(tester);
  });
}
