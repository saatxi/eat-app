import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/data/supabase/identity.dart';
import 'package:eatapp/features/groups/group_scope_button.dart';
import 'package:eatapp/features/groups/groups_controller.dart';
import 'package:eatapp/features/groups/groups_screen.dart';
import 'package:eatapp/features/list/journal_screen.dart';
import 'package:eatapp/features/stats/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/groups/fake_group_gateway.dart';
import '../../data/photo/photo_fakes.dart';
import '../../data/supabase/fake_identity_gateway.dart';

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

  /// A controller with a backend behind it, loaded once so the selector has its
  /// roster before the screen is pumped.
  Future<GroupsController> ready({
    required FakeGroupGateway gateway,
    IdentityGateway? identity,
  }) async {
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: identity ?? FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);
    await controller.load();
    return controller;
  }

  Widget host({required Widget child, GroupsController? groups}) => AppScope(
    restaurants: repository,
    preferences: preferences,
    photoPicker: FakePhotoPicker(),
    groupsController: groups,
    child: MaterialApp(
      theme: AppTheme.of(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );

  FakeGroupGateway twoGroups() => FakeGroupGateway(
    groups: const <Group>[
      Group(id: 'g1', name: 'Família', role: GroupRole.owner),
      Group(id: 'g2', name: 'Amics', role: GroupRole.editor),
    ],
  );

  testWidgets('the app-bar button names the scope and switches it', (
    WidgetTester tester,
  ) async {
    final GroupsController controller = await ready(gateway: twoGroups());

    await tester.pumpWidget(
      host(
        child: Scaffold(
          appBar: AppBar(
            actions: <Widget>[GroupScopeButton(controller: controller)],
          ),
        ),
        groups: controller,
      ),
    );
    await tester.pumpAndSettle();

    // The button names the scope in force, rather than only hinting at it.
    expect(find.text('Personal'), findsOneWidget);

    // The menu names every scope, whichever one is in force.
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Personal'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Família'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Amics'), findsOneWidget);

    await tester.tap(find.widgetWithText(MenuItemButton, 'Amics'));
    await tester.pumpAndSettle();

    expect(preferences.current.selectedGroupId, 'g2');
    // And the label follows the switch.
    expect(find.text('Amics'), findsOneWidget);
    expect(find.text('Personal'), findsNothing);
  });

  testWidgets('the labelled switch still fits the journal app bar', (
    WidgetTester tester,
  ) async {
    // A narrow phone, so the title and the three actions have least room left.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // A deliberately long name: the label has to ellipsize rather than push the
    // title and the other actions off the bar.
    final GroupsController controller = await ready(
      gateway: FakeGroupGateway(
        groups: const <Group>[
          Group(
            id: 'g1',
            name: 'Família del poble de la muntanya',
            role: GroupRole.owner,
          ),
        ],
      ),
    );
    await controller.select('g1');

    await tester.pumpWidget(
      host(
        child: JournalScreen(
          onOpenRestaurant: (_) {},
          onAddRestaurant: () {},
        ),
        groups: controller,
      ),
    );
    // Hand-pumped: the initial load shows a skeleton that never settles. An
    // overflow here would fail the test on its own.
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(GroupScopeButton), findsOneWidget);

    // Tear down while pumping, so drift's deferred stream-cleanup timer is
    // flushed rather than left pending.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  /// Pumps a few frames by hand — both screens show a spinner during their
  /// initial load, and `pumpAndSettle` never returns while one is up — checks
  /// the scope button is in the app bar, then tears the tree down while the
  /// harness is still pumping, so drift's deferred stream-cleanup timer is
  /// flushed rather than left pending and failing the test.
  Future<void> expectScopeButton(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(GroupScopeButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('the scope switch also shows on the statistics screen', (
    WidgetTester tester,
  ) async {
    final GroupsController controller = await ready(gateway: twoGroups());

    await tester.pumpWidget(
      host(child: const StatisticsScreen(), groups: controller),
    );
    await expectScopeButton(tester);
  });

  testWidgets('the groups screen offers no per-tile management menu', (
    WidgetTester tester,
  ) async {
    final GroupsController controller = await ready(gateway: twoGroups());
    await controller.select('g2');

    await tester.pumpWidget(
      host(child: const GroupsScreen(), groups: controller),
    );
    await tester.pumpAndSettle();

    // The list is navigation only: a tile opens its members screen, and
    // renaming, leaving and dissolving a group all live there, so no tile
    // carries an overflow menu.
    expect(find.text('Amics'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('Edit group'), findsNothing);
    expect(find.text('Leave group'), findsNothing);
    expect(find.text('Delete group'), findsNothing);
    // "Change your name" stays a standalone row under the list.
    expect(find.text('Change your name'), findsOneWidget);
  });

  testWidgets('the groups screen creates and selects a group', (
    WidgetTester tester,
  ) async {
    final FakeGroupGateway gateway = FakeGroupGateway();
    final GroupsController controller = await ready(gateway: gateway);

    await tester.pumpWidget(
      host(child: const GroupsScreen(), groups: controller),
    );
    // Hand-pumped: the initial load spinner never settles, so pump a few
    // frames until the list appears, then stop.
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Tap the FAB to create.
    await tester.tap(find.byType(FilledButton).first);
    // Pump frames until the dialog appears (no pumpAndSettle — dialogs
    // with animations can keep settling forever).
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.enterText(find.byType(TextField), 'Family');
    await tester.tap(find.text('Create'));
    // Pump frames for the dialog close + controller reload.
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(<String>[for (final Group group in gateway.created) group.name], <String>['Family']);
    expect(preferences.current.selectedGroupId, gateway.created.single.id);
  });

  testWidgets('the create button is disabled once the owner cap is reached', (
    WidgetTester tester,
  ) async {
    // Two owned groups already — the fake's cap is 2.
    final FakeGroupGateway gateway = FakeGroupGateway(
      groups: const <Group>[
        Group(id: 'g1', name: 'Família', role: GroupRole.owner),
        Group(id: 'g2', name: 'Amics', role: GroupRole.owner),
      ],
    );
    final GroupsController controller = await ready(gateway: gateway);

    await tester.pumpWidget(
      host(child: const GroupsScreen(), groups: controller),
    );
    await tester.pumpAndSettle();

    // The FAB is a disabled FilledButton — no onPressed, so tapping it does
    // nothing and no create dialog opens.
    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(button.onPressed, isNull);
    expect(controller.state.ownerCapReached, isTrue);

    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('the change-your-name row is hidden with no groups', (
    WidgetTester tester,
  ) async {
    final FakeGroupGateway gateway = FakeGroupGateway();
    final GroupsController controller = await ready(gateway: gateway);

    await tester.pumpWidget(
      host(child: const GroupsScreen(), groups: controller),
    );
    await tester.pumpAndSettle();

    // A display name only means something inside a group, so the row is gone
    // when the user belongs to none — while creating one stays available.
    expect(find.text('Change your name'), findsNothing);
    expect(find.byType(FilledButton), findsWidgets);
  });

  testWidgets('creating without an account points to Settings', (
    WidgetTester tester,
  ) async {
    final FakeGroupGateway gateway = FakeGroupGateway();
    // No session: a device that never created an account.
    final GroupsController controller = await ready(
      gateway: gateway,
      identity: FakeIdentityGateway(),
    );

    await tester.pumpWidget(
      host(child: const GroupsScreen(), groups: controller),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.byType(FilledButton).first);
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // No name dialog opens; a message sends the user to Settings instead.
    expect(find.byType(TextField), findsNothing);
    expect(
      find.text('Create an account in Settings → Account before making a group.'),
      findsOneWidget,
    );
    expect(gateway.created, isEmpty);
  });
}
