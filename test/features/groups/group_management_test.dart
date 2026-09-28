import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/groups/group_gateway.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/groups/group_scope_button.dart';
import 'package:eatapp/features/groups/groups_controller.dart';
import 'package:eatapp/features/list/journal_screen.dart';
import 'package:eatapp/features/roulette/roulette_screen.dart';
import 'package:eatapp/features/settings/settings_screen.dart';
import 'package:eatapp/features/stats/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';
import '../../data/supabase/fake_identity_gateway.dart';

/// A hand-written [GroupGateway] fake — no mocking package, per the project's
/// convention.
class _FakeGroupGateway implements GroupGateway {
  _FakeGroupGateway({this.groups = const <Group>[]});

  List<Group> groups;

  /// The groups [createGroup] minted, for assertions.
  final List<Group> created = <Group>[];

  @override
  Future<Group> createGroup({
    required String id,
    required String name,
    required String createdBy,
  }) async {
    final Group group = Group(id: id, name: name, role: GroupRole.owner);
    groups = <Group>[...groups, group];
    created.add(group);
    return group;
  }

  @override
  Future<List<Group>> listGroups(String userId) async => groups;

  @override
  Future<List<GroupMember>> listMembers(String groupId) async =>
      const <GroupMember>[];

  @override
  Future<void> leaveGroup(String groupId, String userId) async {}

  @override
  Future<void> removeMember(String groupId, String userId) async {}

  @override
  Future<void> deleteGroup(String groupId) async {}

  @override
  Future<void> setDisplayName({
    required String userId,
    required String displayName,
  }) async {}
}

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
  Future<GroupsController> ready({required _FakeGroupGateway gateway}) async {
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
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

  _FakeGroupGateway twoGroups() => _FakeGroupGateway(
    groups: const <Group>[
      Group(id: 'g1', name: 'Família', role: GroupRole.owner),
      Group(id: 'g2', name: 'Amics', role: GroupRole.member),
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
      gateway: _FakeGroupGateway(
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

  testWidgets('the scope switch also shows on the roulette and the statistics', (
    WidgetTester tester,
  ) async {
    final GroupsController controller = await ready(gateway: twoGroups());

    await tester.pumpWidget(
      host(child: const RouletteScreen(), groups: controller),
    );
    await expectScopeButton(tester);

    await tester.pumpWidget(
      host(child: const StatisticsScreen(), groups: controller),
    );
    await expectScopeButton(tester);
  });

  testWidgets('the settings Groups section switches the scope', (
    WidgetTester tester,
  ) async {
    final GroupsController controller = await ready(gateway: twoGroups());

    await tester.pumpWidget(
      host(child: const SettingsScreen(), groups: controller),
    );
    await tester.pumpAndSettle();

    // The scope row names the scope in force — Personal, here — and the roster
    // only appears once its menu is open. The row sits below the appearance and
    // language rows, so the lazy list has to be scrolled to it first.
    final Finder scopeRow = find.widgetWithText(ListTile, 'Personal');
    await tester.scrollUntilVisible(scopeRow, 200);
    await tester.ensureVisible(scopeRow);
    await tester.pumpAndSettle();

    await tester.tap(scopeRow);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(MenuItemButton, 'Família'), findsOneWidget);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Família'));
    await tester.pumpAndSettle();

    expect(preferences.current.selectedGroupId, 'g1');
  });

  testWidgets('the settings Groups section creates and selects a group', (
    WidgetTester tester,
  ) async {
    final _FakeGroupGateway gateway = _FakeGroupGateway();
    final GroupsController controller = await ready(gateway: gateway);

    await tester.pumpWidget(
      host(child: const SettingsScreen(), groups: controller),
    );
    await tester.pumpAndSettle();

    final Finder create = find.widgetWithText(ListTile, 'New group');
    await tester.scrollUntilVisible(create, 200);
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();

    await tester.tap(create);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Family');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(<String>[for (final Group group in gateway.created) group.name], <String>['Family']);
    expect(preferences.current.selectedGroupId, gateway.created.single.id);
  });
}
