import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/detail/restaurant_detail_screen.dart';
import 'package:eatapp/features/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';

/// The shell's adaptive layout: the same sections under a bottom bar on a phone
/// and a rail on a tablet, with the detail pushed on one and shown beside the
/// list on the other.
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

  Widget host() => AppScope(
    restaurants: repository,
    preferences: preferences,
    photoPicker: FakePhotoPicker(),
    child: MaterialApp(
      theme: AppTheme.of(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const HomeShell(),
    ),
  );

  /// Pumps the shell at a logical [size] and lets the database's first emission
  /// land.
  ///
  /// Timed pumps rather than `pumpAndSettle`, for the reason `test/widget_test`
  /// gives: the initial-load skeletons pulse forever, so the tree never reaches
  /// a quiet frame while they are on screen.
  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Tears the tree down while the harness is still pumping, so the query
  /// streams' deferred-cleanup timers get flushed.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('a phone-width window keeps the bottom bar and pushes the detail', (
    WidgetTester tester,
  ) async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await pumpShell(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(RestaurantDetailScreen), findsNothing);

    await tester.tap(find.text('Cal Ferran'));
    await tester.pumpAndSettle();

    expect(find.byType(RestaurantDetailScreen), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('a tablet-width window shows a rail and the detail beside the list', (
    WidgetTester tester,
  ) async {
    await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
    await pumpShell(tester, const Size(1200, 900));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Nothing picked yet, so the pane explains itself rather than sitting blank.
    expect(find.text('Nothing selected'), findsOneWidget);
    expect(find.byType(RestaurantDetailScreen), findsNothing);

    await tester.tap(find.text('Cal Ferran'));
    await tester.pumpAndSettle();

    // Selected in place: the detail shows beside the list, the placeholder is
    // gone, and nothing was pushed.
    expect(find.byType(RestaurantDetailScreen), findsOneWidget);
    expect(find.text('Nothing selected'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await disposeApp(tester);
  });
}
