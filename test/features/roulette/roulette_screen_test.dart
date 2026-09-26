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
/// say, so the screen has to be arranged around it rather than the other way
/// round.
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

  /// The reveal's own scroll view: the filter strip above it scrolls sideways,
  /// this one, if it ever has to, scrolls down.
  Finder revealArea() => find.byWidgetPredicate(
    (Widget widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.vertical,
  );

  /// How far the reveal has to scroll to show all of the card. Zero means the
  /// whole card is on screen; anything else means its bottom is cut off.
  double revealOverflow(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: revealArea(), matching: find.byType(Scrollable)),
      )
      .position
      .maxScrollExtent;

  testWidgets('the whole pick card fits on a small phone', (
    WidgetTester tester,
  ) async {
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
    expect(
      revealOverflow(tester),
      0,
      reason: 'nothing of the card may sit below the fold of a phone this size',
    );
    // The button stays outside the reveal, where the tap left it.
    expect(find.text('Try again'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('the filters are all still there, in one strip', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = smallPhone;
    addTearDown(tester.view.reset);

    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await tester.pumpWidget(host(const RouletteScreen()));
    await pump(tester);

    // Scrolled off the right edge or not, every filter is still in the strip
    // above the reveal rather than wrapped onto a second line of it.
    expect(find.text('Favorites only'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('Price'), findsOneWidget);
    expect(find.text('1 restaurant'), findsOneWidget);

    await disposeApp(tester);
  });
}
