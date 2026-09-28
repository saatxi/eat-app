import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/groups/group_gateway.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/groups/group_selector.dart';
import 'package:eatapp/features/groups/groups_controller.dart';
import 'package:eatapp/features/settings/settings_screen.dart';
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

  testWidgets('the journal selector collapses to a dropdown with several groups', (
    WidgetTester tester,
  ) async {
    final GroupsController controller = await ready(gateway: twoGroups());
    await controller.select('g1');

    await tester.pumpWidget(
      host(
        child: Scaffold(body: GroupSelector(controller: controller)),
        groups: controller,
      ),
    );
    await tester.pumpAndSettle();

    // One control labelled with the scope in force, rather than a chip each.
    expect(find.text('Família'), findsOneWidget);
    expect(find.text('Personal'), findsNothing);
    expect(find.text('Amics'), findsNothing);

    // Opening it lists every scope, and picking Personal moves the label.
    await tester.tap(find.text('Família'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Personal'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Amics'), findsOneWidget);

    await tester.tap(find.widgetWithText(MenuItemButton, 'Personal'));
    await tester.pumpAndSettle();

    expect(preferences.current.selectedGroupId, isNull);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Família'), findsNothing);
  });

  testWidgets('the journal selector keeps chips for a single group', (
    WidgetTester tester,
  ) async {
    final GroupsController controller = await ready(
      gateway: _FakeGroupGateway(
        groups: const <Group>[
          Group(id: 'g1', name: 'Família', role: GroupRole.owner),
        ],
      ),
    );

    await tester.pumpWidget(
      host(
        child: Scaffold(body: GroupSelector(controller: controller)),
        groups: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Família'), findsOneWidget);

    await tester.tap(find.text('Família'));
    await tester.pumpAndSettle();
    expect(preferences.current.selectedGroupId, 'g1');

    // The regression the dropdown must not reintroduce: choosing Personal
    // leaves the group reachable, so a group is never Settings-only.
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(preferences.current.selectedGroupId, isNull);
    expect(find.text('Família'), findsOneWidget);
  });

  testWidgets('the settings Groups section switches the scope', (
    WidgetTester tester,
  ) async {
    final GroupsController controller = await ready(gateway: twoGroups());

    await tester.pumpWidget(
      host(child: const SettingsScreen(), groups: controller),
    );
    await tester.pumpAndSettle();

    // The section sits below the appearance and language rows, so the lazy list
    // has to be scrolled to it before the row exists to be tapped.
    final Finder groupRow = find.widgetWithText(ListTile, 'Família');
    await tester.scrollUntilVisible(groupRow, 200);
    await tester.ensureVisible(groupRow);
    await tester.pumpAndSettle();

    await tester.tap(groupRow);
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
