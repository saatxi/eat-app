import 'dart:io';

import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/data/share/restaurant_share_writer.dart';
import 'package:eatapp/features/import_export/import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

/// The review screen for an incoming share file — the last line of defence
/// before a received restaurant reaches the database.
///
/// What it holds down is the screen's own job: which state it shows for a file,
/// that the file's restaurants are only *reviewed*, and that leaving discards
/// the review. What a confirmed import writes is the controller's business, and
/// `import_controller_test` covers it directly.
///
/// Every database call in here goes through `tester.runAsync` (or happens in
/// `setUp`). Inside a `testWidgets` body the clock is faked, and a query awaited
/// under it never completes — which shows up as a test that hangs rather than
/// one that fails.
void main() {
  late AppDatabase db;
  late AppDatabase sourceDb;
  late RestaurantRepository repository;
  late Directory temp;
  late File freshFile;
  late bool done;

  /// A restaurant's worth of data, shared by the file and the duplicate's
  /// existing copy, so the two line up by name *and* street address.
  const String sharedName = 'Cal Ferran';
  const String sharedStreet = 'Carrer 1';

  /// Writes the share file in `setUp`, outside the fake clock, using the real
  /// writer — so the bytes are exactly what the app would have sent.
  Future<File> writeShareFile(
    List<Restaurant> restaurants, {
    String name = 'shared.eatapp',
  }) async {
    final RestaurantRepository source = RestaurantRepository(sourceDb);
    for (final Restaurant row in restaurants) {
      await source.insert(
        restaurant(
          id: row.id,
          name: row.name,
          cuisineType: row.cuisineType,
          streetAddress: row.streetAddress,
        ),
      );
    }
    return writeRestaurantShareFile(
      directory: temp,
      restaurants: await source.exportRestaurants(),
    );
  }

  setUp(() async {
    db = createTestDatabase();
    sourceDb = createTestDatabase();
    repository = RestaurantRepository(db);
    temp = Directory.systemTemp.createTempSync('eatapp-import-test');
    done = false;
    freshFile = await writeShareFile(<Restaurant>[
      restaurant(
        id: 'incoming',
        name: sharedName,
        cuisineType: 'catalan',
        streetAddress: sharedStreet,
      ),
    ]);
  });

  tearDown(() async {
    await db.close();
    await sourceDb.close();
    // Windows can hold a just-released temp directory for a moment, and a
    // leftover directory is not worth failing a test over.
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Nothing to clean up, or nothing that can be cleaned up yet.
    }
  });

  Future<void> pumpImport(WidgetTester tester, String filePath) async {
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
          home: ImportScreen(filePath: filePath, onDone: () => done = true),
        ),
      ),
    );
    await pumpFrames(tester);
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('a file that is not ours is rejected by the format tag', (
    WidgetTester tester,
  ) async {
    final File file = File(p.join(temp.path, 'foreign.eatapp'))
      ..writeAsStringSync('{"restaurants": []}');

    await pumpImport(tester, file.path);

    // Every failure reason shares this title; the body says which one it was.
    expect(find.text("Can't open this file"), findsOneWidget);
    expect(find.text('Import'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('shows the file\'s restaurants for review, writing nothing yet', (
    WidgetTester tester,
  ) async {
    await pumpImport(tester, freshFile.path);

    // Offered with a decision to make...
    expect(find.text(sharedName), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    // ...and nothing written just by looking at it.
    expect(
      await tester.runAsync(() => repository.getAllRestaurants()),
      isEmpty,
    );

    await disposeApp(tester);
  });

  testWidgets('flags a likely duplicate as already in the list', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(
      () => repository.insert(
        restaurant(
          id: 'existing',
          name: sharedName,
          cuisineType: 'italian',
          streetAddress: sharedStreet,
        ),
      ),
    );

    await pumpImport(tester, freshFile.path);

    // The duplicate is folded under its own collapsed header by default, so the
    // header is what proves it was spotted — the card inside only builds once
    // the section is expanded.
    expect(find.text('1 already in your list'), findsOneWidget);
    expect(
      find.text('Already in your list'),
      findsNothing,
      reason: 'the collapsed section has not built its card yet',
    );

    await disposeApp(tester);
  });

  testWidgets('leaving discards the whole review', (WidgetTester tester) async {
    await pumpImport(tester, freshFile.path);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpFrames(tester);

    expect(done, isTrue);
    expect(
      await tester.runAsync(() => repository.getAllRestaurants()),
      isEmpty,
      reason: 'backing out writes nothing',
    );

    await disposeApp(tester);
  });
}

/// Lets the real event loop run, alternating with frames, until the screen has
/// had every chance to catch up.
///
/// Reading the file happens on the real event loop, so pumping alone never lets
/// it finish — the screen would stay on its spinner however many frames were
/// pumped. `runAsync` is what gives it the chance, and several rounds are needed
/// because each read is its own turn. `pumpAndSettle` is not an option: the
/// loading state is a `CircularProgressIndicator`, which never settles.
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
