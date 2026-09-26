import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/edit/restaurant_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

/// The add/edit form as it is actually driven: what it starts with, what it
/// refuses, and what lands in the database afterwards.
///
/// The controller's validation rules have their own tests; this is the wiring
/// around them — the fields reaching the controller, and the screen leaving only
/// once the write succeeded.
/// Lets the real event loop run, alternating with frames, until the screen has
/// had every chance to catch up.
///
/// The form loads a restaurant, its tags and its photo off the database, and
/// that work lives on the real event loop: pumping alone never lets it finish,
/// so the screen would still be on its spinner however many frames were pumped.
/// `runAsync` is what gives it the chance, and several rounds of it are needed
/// because each read is its own turn — `pumpAndSettle` is not an option either,
/// because the loading spinner never settles.
Future<void> pumpFrames(WidgetTester tester) async {
  for (int round = 0; round < 4; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

void main() {
  late AppDatabase db;
  late RestaurantRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
  });

  tearDown(() => db.close());

  /// Pushes the form onto a route: saving pops it, and popping the only route is
  /// not something a test can do.
  Future<void> pumpForm(WidgetTester tester, {String? restaurantId}) async {
    // A tall surface, so the whole form is laid out: it is a lazy `ListView`,
    // and the tags section near the bottom would otherwise never be built — a
    // `find.text` for a tag would then report a false absence.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        restaurants: repository,
        preferences: UserPreferencesRepository(),
        photoPicker: FakePhotoPicker(),
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
                          RestaurantEditScreen(restaurantId: restaurantId),
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
    await pumpFrames(tester);
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<List<Restaurant>> stored() => repository.getAllRestaurants();

  testWidgets('opens empty in add mode', (WidgetTester tester) async {
    await pumpForm(tester);

    expect(find.text('Add restaurant'), findsOneWidget);
    expect(find.text('Select a cuisine'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );

    await disposeApp(tester);
  });

  testWidgets('refuses to save without a name, and writes nothing', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.text('Save'));
    await pumpFrames(tester);

    expect(find.text('Name is required'), findsOneWidget);
    expect(await stored(), isEmpty);
    expect(
      find.byType(RestaurantEditScreen),
      findsOneWidget,
      reason: 'a rejected form stays open',
    );

    await disposeApp(tester);
  });

  testWidgets('adds a restaurant once it has a name and a cuisine', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(find.byType(TextField).first, 'Cal Ferran');
    await tester.pump();
    await tester.tap(find.text('Select a cuisine'));
    await pumpFrames(tester);
    await tester.tap(find.text('Catalan').last);
    await pumpFrames(tester);

    await tester.tap(find.text('Save'));
    await pumpFrames(tester);

    final List<Restaurant> all = await stored();
    expect(all, hasLength(1));
    expect(all.single.name, 'Cal Ferran');
    expect(all.single.cuisineType, 'catalan');
    expect(find.byType(RestaurantEditScreen), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('prefills an existing restaurant and updates it', (
    WidgetTester tester,
  ) async {
    await repository.insert(
      restaurant(
        id: 'a',
        name: 'Cal Ferran',
        cuisineType: 'catalan',
        streetAddress: 'Carrer 1',
      ),
      tags: const <String>['Terraza'],
    );

    await pumpForm(tester, restaurantId: 'a');

    expect(find.text('Edit restaurant'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Cal Ferran',
    );
    expect(find.text('Terraza'), findsOneWidget, reason: 'the tags come back too');

    await tester.enterText(find.byType(TextField).first, 'Cal Ferran Nou');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await pumpFrames(tester);

    final List<Restaurant> all = await stored();
    expect(all, hasLength(1), reason: 'edited, not added');
    expect(all.single.id, 'a');
    expect(all.single.name, 'Cal Ferran Nou');
    expect(all.single.cuisineType, 'catalan');
    expect(all.single.streetAddress, 'Carrer 1');

    await disposeApp(tester);
  });
}
