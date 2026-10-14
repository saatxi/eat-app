import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/groups/groups_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/groups/fake_group_gateway.dart';
import '../../data/supabase/fake_identity_gateway.dart';

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
    final FakeGroupGateway gateway = FakeGroupGateway(
      groups: const <Group>[
        Group(id: 'g1', name: 'Família', role: GroupRole.owner),
        Group(id: 'g2', name: 'Amics', role: GroupRole.editor),
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
    final FakeGroupGateway gateway = FakeGroupGateway(
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
      gateway: FakeGroupGateway(
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

  test('creating a group needs a session, then selects it', () async {
    final FakeGroupGateway gateway = FakeGroupGateway();
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);

    final bool created = await controller.createGroup('Família');

    expect(created, isTrue);
    expect(gateway.created, hasLength(1));
    expect(controller.state.groups.single.name, 'Família');
    expect(
      preferences.current.selectedGroupId,
      gateway.created.single.id,
      reason: 'the new group is selected, so the list switches to it',
    );
  });

  test('creating a group without a session is refused', () async {
    final FakeGroupGateway gateway = FakeGroupGateway();
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: FakeIdentityGateway(),
    );
    addTearDown(controller.dispose);

    expect(await controller.createGroup('Família'), isFalse);
    expect(gateway.created, isEmpty);
  });

  test('a backend failure is recorded rather than thrown', () async {
    final FakeGroupGateway gateway = FakeGroupGateway()
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
    final FakeGroupGateway gateway = FakeGroupGateway(
      groups: const <Group>[
        Group(id: 'g1', name: 'Família', role: GroupRole.owner),
        Group(id: 'g2', name: 'Amics', role: GroupRole.editor),
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
    final FakeGroupGateway gateway = FakeGroupGateway()
      ..error = const GroupLimitException(2);
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

  test('a selection that no longer exists falls back to Personal', () async {
    final FakeGroupGateway gateway = FakeGroupGateway(
      groups: const <Group>[
        Group(id: 'g1', name: 'Família', role: GroupRole.owner),
      ],
    );
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await controller.select('g1');
    expect(controller.state.selectedGroupId, 'g1');

    // An owner dissolves the group: it drops out of the roster on the next load.
    gateway.groups = const <Group>[];
    await controller.load();

    expect(controller.state.selectedGroupId, isNull);
    expect(controller.state.selected, isNull);
    expect(
      preferences.current.selectedGroupId,
      isNull,
      reason: 'the dead selection is cleared, not left pointing at nothing',
    );
  });
}
