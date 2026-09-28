import 'package:eatapp/data/groups/group_gateway.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/groups/groups_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/supabase/fake_identity_gateway.dart';

/// A hand-written [GroupGateway] fake — no mocking package, per the project's
/// convention.
class _FakeGroupGateway implements GroupGateway {
  _FakeGroupGateway({this.groups = const <Group>[]});

  List<Group> groups;

  /// Throw to simulate a backend failure.
  Object? error;

  /// The groups [createGroup] minted, for assertions.
  final List<Group> created = <Group>[];

  @override
  Future<Group> createGroup({
    required String id,
    required String name,
    required String createdBy,
  }) async {
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    final Group group = Group(id: id, name: name, role: GroupRole.owner);
    groups = <Group>[...groups, group];
    created.add(group);
    return group;
  }

  @override
  Future<int> ownerGroupLimit() async => 2;

  @override
  Future<List<Group>> listGroups(String userId) async {
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return groups;
  }

  @override
  Future<List<GroupMember>> listMembers(String groupId) async =>
      const <GroupMember>[];

  @override
  Future<void> leaveGroup(String groupId, String userId) async {}

  @override
  Future<void> removeMember(String groupId, String userId) async {}

  @override
  Future<void> editGroup(String groupId, String name) async {
    groups = <Group>[
      for (final Group group in groups)
        group.id == groupId ? Group(id: group.id, name: name, role: group.role) : group,
    ];
  }

  @override
  Future<void> deleteGroup(String groupId) async {}

  @override
  Future<void> setDisplayName({
    required String userId,
    required String displayName,
  }) async {}
}

void main() {
  late UserPreferencesRepository preferences;

  setUp(() {
    preferences = UserPreferencesRepository();
  });

  test('with no backend it is idle and offers no groups', () async {
    final GroupsController controller = GroupsController(
      preferences: preferences,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.canUseGroups, isFalse);
    expect(controller.state.groups, isEmpty);
    expect(controller.state.isLoading, isFalse);
  });

  test("loads the signed-in user's groups", () async {
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      groups: const <Group>[
        Group(id: 'g1', name: 'Família', role: GroupRole.owner),
        Group(id: 'g2', name: 'Amics', role: GroupRole.member),
      ],
    );
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.groups.map((Group g) => g.id), <String>['g1', 'g2']);
    expect(controller.state.error, isNull);
  });

  test('a device that never signed in has no groups yet', () async {
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      groups: const <Group>[
        Group(id: 'g1', name: 'Família', role: GroupRole.owner),
      ],
    );
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: FakeIdentityGateway(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.groups, isEmpty);
  });

  test('selecting a group persists it and follows the preference', () async {
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: _FakeGroupGateway(
        groups: const <Group>[
          Group(id: 'g1', name: 'Família', role: GroupRole.owner),
        ],
      ),
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.select('g1');

    expect(preferences.current.selectedGroupId, 'g1');
    expect(controller.state.selectedGroupId, 'g1');
    expect(controller.state.selected?.name, 'Família');

    await controller.select(null);
    expect(controller.state.selected, isNull);
  });

  test('creating a group signs in first, then selects it', () async {
    final _FakeGroupGateway gateway = _FakeGroupGateway();
    final FakeIdentityGateway identity = FakeIdentityGateway();
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: identity,
    );
    addTearDown(controller.dispose);

    final bool created = await controller.createGroup('Família');

    expect(created, isTrue);
    expect(
      identity.signInCount,
      1,
      reason: 'a group needs an owner, so the first creation signs in',
    );
    expect(gateway.created, hasLength(1));
    expect(controller.state.groups.single.name, 'Família');
    expect(
      preferences.current.selectedGroupId,
      gateway.created.single.id,
      reason: 'the new group is selected, so the list switches to it',
    );
  });

  test('a backend failure is recorded rather than thrown', () async {
    final _FakeGroupGateway gateway = _FakeGroupGateway()
      ..error = Exception('offline');
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.error, isNotNull);
    expect(controller.state.groups, isEmpty);
  });

  test('load reads the owner cap and detects when it is reached', () async {
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      groups: const <Group>[
        Group(id: 'g1', name: 'Família', role: GroupRole.owner),
        Group(id: 'g2', name: 'Amics', role: GroupRole.member),
      ],
    );
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);

    await controller.load();

    // The fake reports a limit of 2; the user owns exactly one group.
    expect(controller.state.ownerGroupLimit, 2);
    expect(controller.state.ownedGroupsCount, 1);
    expect(controller.state.ownerCapReached, isFalse);

    gateway.groups = <Group>[
      ...gateway.groups,
      const Group(id: 'g3', name: 'Feina', role: GroupRole.owner),
    ];
    await controller.load();

    expect(controller.state.ownedGroupsCount, 2);
    expect(controller.state.ownerCapReached, isTrue);
  });

  test('a rejected creation records a GroupLimitException', () async {
    final _FakeGroupGateway gateway = _FakeGroupGateway()
      ..error = GroupLimitException(2);
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);

    final bool created = await controller.createGroup('Nou');

    expect(created, isFalse);
    expect(controller.state.error, isA<GroupLimitException>());
    expect(controller.state.groups, isEmpty);
    expect(preferences.current.selectedGroupId, isNull);
  });
}
