import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/core/theme/journal_density.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/data/supabase/identity.dart';
import 'package:eatapp/features/detail/restaurant_detail_screen.dart';
import 'package:eatapp/features/edit/restaurant_edit_screen.dart';
import 'package:eatapp/features/groups/groups_controller.dart';
import 'package:eatapp/features/list/journal_screen.dart';
import 'package:eatapp/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/groups/fake_group_gateway.dart';
import '../../data/photo/photo_fakes.dart';
import '../../data/supabase/fake_identity_gateway.dart';

/// The app under a large system text size.
///
/// The editorial type scale is deliberately generous, which is exactly what
/// makes it easy to overflow a row, a chip or an app bar once a user doubles
/// it. Nothing here asserts a *layout* — a render overflow is reported as a
/// framework error, so simply laying the screens out at scale is the assertion,
/// and a regression fails the test on the error rather than on a golden.
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late UserPreferencesRepository preferences;
  late Directory photoDir;
  late File photoFile;

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
    photoDir = Directory.systemTemp.createTempSync('eatapp_scale_photo');
    photoFile = File('${photoDir.path}/photo.png')
      ..writeAsBytesSync(_onePixelPng);
  });

  tearDown(() {
    // Best-effort: Windows keeps a handle on the file the image decoder read,
    // so the directory is often still locked when the test ends. Leaving a
    // one-pixel PNG behind in the system temp dir is harmless; failing the
    // test on it would not be.
    try {
      photoDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Left for the OS to clean up.
    }
    return db.close();
  });

  Widget host(
    Widget screen, {
    required double scale,
    IdentityGateway? identity,
    Locale locale = const Locale('en'),
    GroupsController? groups,
  }) => AppScope(
    restaurants: repository,
    preferences: preferences,
    photoPicker: FakePhotoPicker(),
    identity: identity,
    groupsController: groups,
    child: MaterialApp(
      theme: AppTheme.of(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: screen,
        ),
      ),
    ),
  );

  /// A restaurant with every optional field filled in, so the tallest row and
  /// the busiest detail screen are what get scaled.
  Future<void> seed() async {
    await repository.insert(
      restaurant(
        id: 'a',
        name: 'Cal Ferran',
        cuisineType: 'catalan',
        streetAddress: 'Carrer de la Marina 123, baixos',
        city: 'Barcelona',
        region: 'Catalunya',
        country: 'Espanya',
        priceRange: 5,
      ),
    );
    await repository.saveSingleVisit(
      restaurantId: 'a',
      visited: true,
      rating: 4,
      notes: 'Demanar la burrata i seure a la terrassa.',
    );
  }

  /// Pumped by hand rather than with `pumpAndSettle`: the initial-load skeletons
  /// pulse forever, so the tree never goes quiet while they are on screen.
  Future<void> pump(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The edit form reads its restaurant and its photo off the database, and
  /// that work lives on the real event loop: pumping alone never lets it
  /// finish, so the screen would stay on its spinner however many frames were
  /// pumped. `runAsync` is what gives it the chance, several rounds of it
  /// because each read is its own turn.
  Future<void> pumpForm(WidgetTester tester) async {
    for (int round = 0; round < 4; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await pump(tester);
    }
  }

  /// Tears the tree down while the harness is still pumping.
  ///
  /// Cancelling a drift query stream schedules a deferred-cleanup timer, so the
  /// tree has to come down and one more frame be pumped before the test ends —
  /// otherwise the harness fails the test on a timer the widget tree was never
  /// given the chance to flush. See `test/widget_test.dart`.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  for (final double scale in <double>[1.3, 2.0]) {
    testWidgets('the list lays out at ${scale}x text', (
      WidgetTester tester,
    ) async {
      await seed();
      await tester.pumpWidget(
        host(const JournalScreen(), scale: scale),
      );
      await pump(tester);

      expect(find.text('Cal Ferran'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('the detail lays out at ${scale}x text', (
      WidgetTester tester,
    ) async {
      await seed();
      await tester.pumpWidget(
        host(const RestaurantDetailScreen(restaurantId: 'a'), scale: scale),
      );
      await pump(tester);

      expect(find.text('Cal Ferran'), findsWidgets);

      await disposeApp(tester);
    });

    testWidgets('the empty state lays out at ${scale}x text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(const JournalScreen(), scale: scale),
      );
      await pump(tester);

      expect(find.text('No restaurants yet'), findsOneWidget);

      await disposeApp(tester);
    });

    // The edit form's photo section on a narrow phone, in the longest locale.
    //
    // Catalan's "Afegeix una foto"/"Suprimeix la foto" are half again as long
    // as the English template, and before the remove action moved onto the
    // preview as an icon the two labelled buttons overflowed the row at 360dp.
    testWidgets('the edit form lays out in Catalan at ${scale}x text', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await seed();
      // A real file: `Image.file` on a missing path takes its `errorBuilder`
      // and collapses, which would quietly stop laying the preview out at all.
      await repository.setRestaurantPhoto('a', photoFile.path);

      await tester.pumpWidget(
        host(
          const RestaurantEditScreen(restaurantId: 'a'),
          scale: scale,
          locale: const Locale('ca'),
        ),
      );
      await pumpForm(tester);

      expect(find.byTooltip('Suprimeix la foto'), findsOneWidget);

      await disposeApp(tester);
    });

    // The Journal's selection bar on a narrow phone, in the longest locale: the
    // count in the title shares the bar with the close button and two actions,
    // which stay icon-only so a translated label never crowds it out. The fully
    // filled card below it is the narrowest place the rating and price pill have
    // to share a line, and they wrap rather than overflow.
    testWidgets('the selection bar lays out in Catalan at ${scale}x text', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await seed();
      final GroupsController groups = GroupsController(
        preferences: preferences,
        gateway: FakeGroupGateway(
          groups: const <Group>[
            Group(id: 'g1', name: 'Família', role: GroupRole.owner),
          ],
        ),
        identity: FakeIdentityGateway(existingUserId: 'u1'),
      );
      addTearDown(groups.dispose);
      await groups.load();

      await tester.pumpWidget(
        host(
          const JournalScreen(),
          scale: scale,
          locale: const Locale('ca'),
          groups: groups,
        ),
      );
      await pump(tester);
      await tester.longPress(find.text('Cal Ferran'));
      await pump(tester);

      expect(find.text('1 seleccionat'), findsOneWidget);
      expect(find.byTooltip('Afegeix a un grup'), findsOneWidget);

      await disposeApp(tester);
    });

    // The compact Journal card on a narrow phone, in the longest locale: the
    // name and the cuisine-and-town line each have to ellipsize within the
    // shorter card rather than overflow.
    testWidgets('the compact list lays out in Catalan at ${scale}x text', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await seed();
      await repository.insert(
        restaurant(
          id: 'b',
          name: 'Restaurant amb un nom especialment llarg de debò',
          cuisineType: 'mediterranean',
          city: 'Sant Cugat del Vallès',
          priceRange: 6,
        ),
      );
      await preferences.setJournalDensity(JournalDensity.compact);

      await tester.pumpWidget(
        host(const JournalScreen(), scale: scale, locale: const Locale('ca')),
      );
      await pump(tester);

      expect(find.text('Cal Ferran'), findsOneWidget);

      await disposeApp(tester);
    });
  }

  // A narrow phone at the normal text scale: the signed-in account card has two
  // long action labels, and before it used an OverflowBar they overflowed the
  // row instead of stacking. No text-scale loop here — the theme SegmentedButton
  // above it is a separate, unrelated constraint at 2x.
  testWidgets('the signed-in account card fits a narrow phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        const SettingsScreen(),
        scale: 1.0,
        identity: FakeIdentityGateway(
          existingUserId: 'u-1',
          storedCode: 'ABCDEFGH2345WXYZ',
        ),
      ),
    );
    await pump(tester);

    expect(find.text("You're signed in"), findsOneWidget);
    expect(find.byTooltip('Delete profile'), findsOneWidget);

    await disposeApp(tester);
  });
}

/// The smallest valid PNG, so `Image.file` has a real file to decode.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9'
  'awAAAABJRU5ErkJggg==',
);
