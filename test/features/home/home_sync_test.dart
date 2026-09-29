import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/groups/groups_controller.dart';
import 'package:eatapp/features/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';
import '../../data/sync/recording_sync_service.dart';

/// Pushes a lifecycle message onto the channel the binding listens on, so an
/// observer sees a real transition — the way the OS delivers one. Deliberately
/// not async: the discarded future is fine here, and awaiting it would hang
/// under the fake clock a `testWidgets` body runs on.
void _sendLifecycle(WidgetTester tester, String state) {
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    SystemChannels.lifecycle.codec.encodeMessage(state),
    (data) {},
  );
}

/// The group pulls the shell drives for the user with no manual action:
/// entering (or re-tapping) a scope-aware section, and returning to the app
/// from the background. Both go through the one [GroupsController].
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late UserPreferencesRepository preferences;
  late RecordingSyncService syncService;
  late GroupsController controller;

  const String groupId = 'g1';

  setUp(() async {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
    // A persisted selection is what makes syncNow do anything; the controller
    // reads it as it is built.
    await preferences.setSelectedGroup(groupId);
    syncService = RecordingSyncService(db);
    // No gateway: these tests are about *when* a pull is triggered, not how the
    // roster loads. GroupsController.syncNow needs only the sync service and a
    // selected group.
    controller = GroupsController(
      preferences: preferences,
      sync: syncService,
    );
  });

  tearDown(() async {
    controller.dispose();
    syncService.dispose();
    await db.close();
  });

  Widget host() => AppScope(
    restaurants: repository,
    preferences: preferences,
    photoPicker: FakePhotoPicker(),
    groupsController: controller,
    sync: syncService,
    child: MaterialApp(
      theme: AppTheme.of(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const HomeShell(),
    ),
  );

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    // Timed pumps, not pumpAndSettle: the initial-load skeletons pulse forever.
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

  testWidgets('entering a scope-aware section pulls the selected group', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);
    expect(syncService.syncedGroups, isEmpty, reason: 'nothing asked yet');

    // The Roulette is scope-aware; opening it is "entering the group".
    await tester.tap(find.byIcon(Icons.casino_outlined));
    await tester.pump();

    expect(syncService.syncedGroups, <String>[groupId]);

    await disposeApp(tester);
  });

  testWidgets('entering Groups or Settings does not pull', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    // Settings is the last tab and reads no group-scoped rows.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();

    expect(syncService.syncedGroups, isEmpty);

    await disposeApp(tester);
  });

  testWidgets('returning to the app from the background pulls the group', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);
    expect(syncService.syncedGroups, isEmpty);

    // Leave, then come back: only the resumed edge should sync.
    _sendLifecycle(tester, 'AppLifecycleState.paused');
    await tester.pump();
    expect(syncService.syncedGroups, isEmpty, reason: 'pausing is not resume');

    _sendLifecycle(tester, 'AppLifecycleState.resumed');
    await tester.pump();

    expect(syncService.syncedGroups, <String>[groupId]);

    await disposeApp(tester);
  });

  testWidgets('pulling the Journal down pulls the group', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);
    expect(syncService.syncedGroups, isEmpty);

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(syncService.syncedGroups, <String>[groupId]);

    await disposeApp(tester);
  });
}
