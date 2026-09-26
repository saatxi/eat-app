import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/core/widgets/price_range_picker.dart';
import 'package:eatapp/core/widgets/rating_picker.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/log_visit/log_visit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

/// The log-visit form as it is actually driven: filling in the fields, saving,
/// and what ends up in the database afterwards.
///
/// The controller's own rules are covered in `log_visit_controller_test`; what
/// this holds down is the wiring — that the widgets reach the controller and
/// that saving writes a real visit and leaves the screen.
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late FakePhotoPicker picker;

  setUp(() async {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    picker = FakePhotoPicker();
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
  });

  tearDown(() => db.close());

  /// Pushes the screen onto a route rather than making it the root.
  ///
  /// Saving pops the screen, and popping the *only* route is not something a
  /// test can do — so there has to be something underneath to pop back to.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        restaurants: repository,
        preferences: UserPreferencesRepository(),
        photoPicker: picker,
        child: MaterialApp(
          theme: AppTheme.of(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const LogVisitScreen(restaurantId: 'a'),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Lets the real event loop run, then advances the frames.
  ///
  /// The save writes to the database on the real event loop, so pumping alone
  /// never lets it finish. `pumpAndSettle` is not an option either: the save
  /// button becomes a `CircularProgressIndicator` while the write is in flight
  /// and that never settles.
  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<List<Visit>> visits() =>
      repository.observeVisitsForRestaurant('a').first;

  testWidgets('opens on a blank form with the pickers and a save action', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byType(RatingPicker), findsOneWidget);
    expect(find.byType(PriceRangePicker), findsOneWidget);
    // The date field and the note, in that order.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('saves the rating, the price band and the note', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    // The fourth star.
    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();
    // The third euro band.
    await tester.tap(find.text('20-30 €'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Demanar la burrata');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.check));
    await pumpFrames(tester);

    final List<Visit> saved = await visits();
    expect(saved, hasLength(1));
    expect(saved.single.rating, 4);
    expect(saved.single.priceRange, 3);
    expect(saved.single.notes, 'Demanar la burrata');

    // And the screen is gone, i.e. it popped back to the opener.
    expect(find.byType(LogVisitScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('defaults the date to today', (WidgetTester tester) async {
    await pumpScreen(tester);

    final TextField dateField = tester.widget<TextField>(
      find.byType(TextField).first,
    );

    expect(dateField.readOnly, isTrue);
    expect(dateField.controller!.text, isNotEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('tapping the date opens a picker', (WidgetTester tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a picked photo is staged, and can be removed again', (
    WidgetTester tester,
  ) async {
    picker.nextPath = '/tmp/picked.jpg';
    await pumpScreen(tester);

    expect(find.byIcon(Icons.cancel), findsNothing);

    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();

    expect(picker.pickCount, 1);
    expect(find.byIcon(Icons.cancel), findsOneWidget);

    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cancel), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('backing out of the picker stages nothing', (
    WidgetTester tester,
  ) async {
    picker.nextPath = null;
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();

    expect(picker.pickCount, 1, reason: 'the picker was still reached');
    expect(find.byIcon(Icons.cancel), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
