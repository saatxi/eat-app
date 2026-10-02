import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/groups/group_gateway.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/groups/groups_controller.dart';
import 'package:eatapp/features/groups/members_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';
import '../../data/supabase/fake_identity_gateway.dart';

/// A hand-written [GroupGateway] fake covering the roster and the membership
/// calls, and mirroring the server's invariant that a group dissolves when its
/// last member leaves.
class _FakeGroupGateway implements GroupGateway {
  _FakeGroupGateway({
    this.groups = const <Group>[],
    this.members = const <GroupMember>[],
  });

  List<Group> groups;
  List<GroupMember> members;

  /// The users whose leave went through, for assertions.
  final List<String> left = <String>[];

  /// The users an owner removed, for assertions.
  final List<String> removed = <String>[];

  /// The groups an owner dissolved, for assertions.
  final List<String> deleted = <String>[];

  /// The display names [setDisplayName] stored, keyed by user id.
  final Map<String, String> names = <String, String>{};

  /// The names [editGroup] stored, keyed by group id.
  final Map<String, String> renamed = <String, String>{};

  @override
  Future<List<GroupMember>> listMembers(String groupId) async => members;

  @override
  Future<int> ownerGroupLimit() async => 2;

  @override
  Future<List<Group>> listGroups(String userId) async => groups;

  @override
  Future<void> setRole(String groupId, String userId, GroupRole role) async {}

  @override
  Future<void> setDisplayName({
    required String userId,
    required String displayName,
  }) async {
    names[userId] = displayName;
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) async {
    left.add(userId);
    members = <GroupMember>[
      for (final GroupMember member in members)
        if (member.userId != userId) member,
    ];
    // The server's `group_members_dissolve_when_empty` trigger: no members
    // left means the group (and its cascade) go away.
    if (members.isEmpty) {
      groups = <Group>[
        for (final Group group in groups)
          if (group.id != groupId) group,
      ];
    }
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    removed.add(userId);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    deleted.add(groupId);
    members = const <GroupMember>[];
  }

  @override
  Future<void> editGroup(String groupId, String name) async {
    renamed[groupId] = name;
    groups = <Group>[
      for (final Group group in groups)
        group.id == groupId
            ? Group(id: group.id, name: name, role: group.role)
            : group,
    ];
  }

  @override
  Future<Group> createGroup({
    required String id,
    required String name,
  }) async => throw UnimplementedError();
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

  Widget host({
    required GroupGateway groups,
    required Widget child,
    GroupsController? groupsController,
  }) => AppScope(
    restaurants: repository,
    preferences: preferences,
    photoPicker: FakePhotoPicker(),
    groups: groups,
    groupsController: groupsController,
    identity: FakeIdentityGateway(existingUserId: 'u1'),
    child: MaterialApp(
      theme: AppTheme.of(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );

  testWidgets('member names are informational and open no editor', (
    WidgetTester tester,
  ) async {
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.owner),
        GroupMember(
          userId: 'u2',
          displayName: 'Maria',
          role: GroupRole.editor,
        ),
      ],
    );
    const Group group = Group(id: 'g1', name: 'Família', role: GroupRole.owner);

    await tester.pumpWidget(
      host(groups: gateway, child: const MembersScreen(group: group)),
    );
    await tester.pumpAndSettle();

    // Both names are shown, and there is no rename affordance anywhere.
    expect(find.textContaining('Me'), findsOneWidget);
    expect(find.textContaining('Maria'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byType(TextField), findsNothing);

    // Tapping a name must not open a rename dialog or write anything.
    await tester.tap(find.textContaining('Maria'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(gateway.names, isEmpty);
  });

  testWidgets('leaving as the last member warns that the group will dissolve', (
    WidgetTester tester,
  ) async {
    // A single-member roster: leaving means the group disappears too.
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.owner),
      ],
    );
    const Group group = Group(id: 'g1', name: 'Solo', role: GroupRole.owner);

    await tester.pumpWidget(
      host(groups: gateway, child: const MembersScreen(group: group)),
    );
    await tester.pumpAndSettle();

    // Open the overflow menu and pick "Leave group".
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave group'));
    await tester.pumpAndSettle();

    // The confirmation spells out the deletion, not just lost access.
    expect(
      find.textContaining('export the data first'),
      findsOneWidget,
    );
  });

  testWidgets('leaving with others present uses the plain leave copy', (
    WidgetTester tester,
  ) async {
    // "Me" is a plain member (not the owner) leaving while the owner remains,
    // so the menu legitimately offers "Leave group".
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.editor),
        GroupMember(userId: 'u2', displayName: 'Alice', role: GroupRole.owner),
      ],
    );
    const Group group = Group(id: 'g1', name: 'Família', role: GroupRole.editor);

    await tester.pumpWidget(
      host(groups: gateway, child: const MembersScreen(group: group)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave group'));
    await tester.pumpAndSettle();

    // The ordinary leave wording references the other members who keep access.
    expect(
      find.textContaining('stay with the other members'),
      findsOneWidget,
    );
    expect(
      find.textContaining('export the data first'),
      findsNothing,
    );
  });

  testWidgets(
    'leaving as the last member dissolves the group and drops it from the list',
    (WidgetTester tester) async {
      // A single-member group, currently selected.
      final _FakeGroupGateway gateway = _FakeGroupGateway(
        groups: const <Group>[
          Group(id: 'g1', name: 'Solo', role: GroupRole.owner),
        ],
        members: const <GroupMember>[
          GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.owner),
        ],
      );
      final GroupsController groupsController = GroupsController(
        preferences: preferences,
        gateway: gateway,
        identity: FakeIdentityGateway(existingUserId: 'u1'),
      );
      addTearDown(groupsController.dispose);
      await groupsController.load();
      expect(groupsController.state.groups, hasLength(1));
      await preferences.setSelectedGroup('g1');

      const Group group = Group(
        id: 'g1',
        name: 'Solo',
        role: GroupRole.owner,
      );

      // A base route to return to after the members screen pops itself.
      await tester.pumpWidget(
        host(
          groups: gateway,
          groupsController: groupsController,
          child: const Scaffold(
            body: Center(child: Text('base')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              const MembersScreen(group: group),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave group'));
      await tester.pumpAndSettle();

      // The last-member confirmation appears and is accepted.
      expect(find.textContaining('export the data first'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Leave reached the gateway, and the group is gone for good.
      expect(gateway.left, <String>['u1']);
      expect(gateway.groups, isEmpty);

      // The selection fell back to Personal and the shared roster reloaded, so
      // the dissolved group is no longer in the groups list.
      expect(preferences.current.selectedGroupId, isNull);
      expect(groupsController.state.groups, isEmpty);

      // The members screen popped itself back to the base route.
      expect(find.text('base'), findsOneWidget);
      expect(find.byType(MembersScreen), findsNothing);
    },
  );

  testWidgets('an owner renames the group from the overflow menu', (
    WidgetTester tester,
  ) async {
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      groups: const <Group>[
        Group(id: 'g1', name: 'Família', role: GroupRole.owner),
      ],
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.owner),
      ],
    );
    const Group group = Group(id: 'g1', name: 'Família', role: GroupRole.owner);

    await tester.pumpWidget(
      host(groups: gateway, child: const MembersScreen(group: group)),
    );
    await tester.pumpAndSettle();

    // Rename sits first in the menu, above the destructive actions.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit group'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Amics');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(gateway.renamed['g1'], 'Amics');
    // The app-bar title follows the rename in place.
    expect(find.text('Amics'), findsOneWidget);
  });
}