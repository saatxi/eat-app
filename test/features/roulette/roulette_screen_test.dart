import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/roulette/roulette_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

/// The reveal itself: the card is as tall as what it has to say, so the screen
/// has to cope with a window that is shorter than that.
///
/// Nothing here asserts a layout — a render overflow is reported as a framework
/// error, so simply laying the screen out in a short window is the assertion,
/// the same way `test/features/accessibility/text_scale_test.dart` uses a large
/// text size.
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

  /// Pumped by hand rather than with `pumpAndSettle`: the first-load spinner
  /// never settles.
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

  testWidgets('the reveal scrolls rather than overflowing a short window', (
    WidgetTester tester,
  ) async {
    // A small phone, taken down to a window shorter than the pick card: the
    // filter row, the button and the reveal all have to fit above the fold of a
    // screen this size, and the card is the one piece with a fixed height.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 420);
    addTearDown(tester.view.reset);

    await repository.insert(
      restaurant(
        id: 'a',
        name: 'Cal Ferran',
        cuisineType: 'catalan',
        streetAddress: 'Carrer de la Marina 123',
        priceRange: 3,
      ),
    );
    await tester.pumpWidget(host(const RouletteScreen()));
    await pump(tester);

    await tester.tap(find.text('Pick one'));
    await pump(tester);

    expect(find.text('Cal Ferran'), findsOneWidget);
    // The button stays outside the scrolling area, where the tap left it.
    expect(find.text('Try again'), findsOneWidget);

    await disposeApp(tester);
  });
}
