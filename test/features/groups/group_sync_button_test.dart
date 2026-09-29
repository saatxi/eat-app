import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/data/sync/sync_service.dart';
import 'package:eatapp/features/groups/group_sync_button.dart';
import 'package:eatapp/features/groups/groups_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/sync/recording_sync_service.dart';

/// The Journal's one-tap "sync now": present only with a group selected, a
/// spinner while a pull runs, and a retry cloud when the last one failed.
void main() {
  late AppDatabase db;
  late UserPreferencesRepository preferences;
  late RecordingSyncService syncService;

  setUp(() {
    db = createTestDatabase();
    preferences = UserPreferencesRepository();
    syncService = RecordingSyncService(db);
  });

  tearDown(() async {
    syncService.dispose();
    await db.close();
  });

  Widget host(GroupsController controller) => MaterialApp(
    theme: AppTheme.of(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      appBar: AppBar(actions: <Widget>[GroupSyncButton(controller: controller)]),
    ),
  );

  testWidgets('with a group selected it shows, and tapping pulls it', (
    WidgetTester tester,
  ) async {
    await preferences.setSelectedGroup('g1');
    final GroupsController controller = GroupsController(
      preferences: preferences,
      sync: syncService,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(controller));
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.sync_rounded));
    await tester.pump();

    expect(syncService.syncedGroups, <String>['g1']);
  });

  testWidgets('in Personal mode it is absent', (WidgetTester tester) async {
    final GroupsController controller = GroupsController(
      preferences: preferences,
      sync: syncService,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(controller));

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('with no sync service it is absent', (WidgetTester tester) async {
    await preferences.setSelectedGroup('g1');
    final GroupsController controller = GroupsController(
      preferences: preferences,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(controller));

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('a failed pull turns the button into a retry cloud', (
    WidgetTester tester,
  ) async {
    await preferences.setSelectedGroup('g1');
    final GroupsController controller = GroupsController(
      preferences: preferences,
      sync: syncService,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(controller));
    syncService.status.value = SyncStatus.failed;
    await tester.pump();

    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsNothing);
    // The failure is not silent: a snackbar says so.
    expect(find.text('Sync failed — tap to retry'), findsOneWidget);

    // Let the snackbar time out so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
  });
}
