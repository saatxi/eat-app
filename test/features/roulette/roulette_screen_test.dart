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

/// The reveal itself, on a phone: the pick card is as tall as what it has to
/// say, and so is the filter block above it, and the two have to share a window
/// that is not quite tall enough for both at full size.
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

  /// A small phone: 360x536 is what this screen gets on a 360x616 window with
  /// the shell's bottom bar under it, which is where the pick card used to be
  /// cut off.
  const Size smallPhone = Size(360, 536);

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

  testWidgets('the whole pick card is on screen', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = smallPhone;
    addTearDown(tester.view.reset);

    // An address is what makes the card its tallest.
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
    // The reveal scales the card down to fit rather than letting it spill past
    // its box, so its bottom edge sits above the button — nothing is cut off.
    expect(
      tester.getBottomLeft(find.byType(Card)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(FilledButton)).dy),
    );
    expect(tester.takeException(), isNull);

    await disposeApp(tester);
  });

  testWidgets('the filter chips wrap rather than run off the edge', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = smallPhone;
    addTearDown(tester.view.reset);

    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await tester.pumpWidget(host(const RouletteScreen()));
    await pump(tester);

    // A wrapping row never clips a chip at the right edge: each one is fully on
    // screen, at whatever line it landed on.
    final double rightEdge = tester.view.physicalSize.width;
    for (final String label in <String>[
      'Favorites only',
      'Status',
      'Rating',
      'Price',
      '1 restaurant',
    ]) {
      final Rect rect = tester.getRect(find.text(label));
      expect(rect.right, lessThanOrEqualTo(rightEdge), reason: '$label is cut');
    }

    await disposeApp(tester);
  });
}
