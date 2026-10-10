import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/core/theme/journal_density.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/list/journal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

/// The Journal's "Compact" density: a shorter card that drops the street but
/// keeps everything a screen reader announces.
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late UserPreferencesRepository preferences;

  // Seeded here rather than in the test body: a drift write awaited under the
  // fake clock a `testWidgets` body runs on never completes.
  setUp(() async {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
    await repository.insert(
      restaurant(
        id: 'a',
        name: 'Cal Ferran',
        cuisineType: 'catalan',
        streetAddress: 'Carrer de la Marina 123',
        city: 'Barcelona',
        country: 'Espanya',
        priceRange: 3,
      ),
    );
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
      home: JournalScreen(onOpenRestaurant: (_) {}),
    ),
  );

  /// Hand-pumped: the initial-load skeletons pulse forever, and the database's
  /// answers live on the real event loop, which only `runAsync` reaches.
  Future<void> pump(WidgetTester tester) async {
    for (int round = 0; round < 3; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder streetLine() => find.textContaining('Carrer de la Marina');

  testWidgets('the normal card shows the whole address', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host());
    await pump(tester);

    expect(streetLine(), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('a compact card shows only the name, cuisine and town', (
    WidgetTester tester,
  ) async {
    await preferences.setJournalDensity(JournalDensity.compact);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(host());
    await pump(tester);

    expect(find.text('Catalan · Barcelona'), findsOneWidget);
    expect(streetLine(), findsNothing);
    expect(find.text('20-30 €'), findsNothing);
    expect(find.text('Want to try'), findsNothing);
    expect(find.byTooltip('Add to favorites'), findsOneWidget);
    // Everything is still announced: only the visual card got shorter.
    expect(
      find.bySemanticsLabel(
        RegExp('Carrer de la Marina 123.*Want to try'),
      ),
      findsOneWidget,
    );

    semantics.dispose();
    await disposeApp(tester);
  });

  testWidgets('switching the density re-lays the open list out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host());
    await pump(tester);
    expect(streetLine(), findsOneWidget);

    await preferences.setJournalDensity(JournalDensity.compact);
    await pump(tester);

    expect(streetLine(), findsNothing);

    await disposeApp(tester);
  });
}
