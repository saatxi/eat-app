import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/features/groups/members_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/groups/fake_group_gateway.dart';
import '../../data/supabase/fake_identity_gateway.dart';

void main() {
  test('loads the roster and marks the current user', () async {
    final FakeGroupGateway gateway = FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.owner),
        GroupMember(userId: 'u2', displayName: 'Maria', role: GroupRole.editor),
      ],
    );
    final MembersController controller = MembersController(
      groupId: 'g1',
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.members, hasLength(2));
    expect(controller.state.currentUserId, 'u1');
    expect(controller.state.error, isNull);
  });

  test('a removal drops the member and reloads', () async {
    final FakeGroupGateway gateway = FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.owner),
        GroupMember(userId: 'u2', displayName: 'Maria', role: GroupRole.editor),
      ],
    );
    final MembersController controller = MembersController(
      groupId: 'g1',
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);
    await controller.load();

    expect(await controller.removeMember('u2'), isTrue);

    expect(gateway.removed, <String>['u2']);
    expect(controller.state.members.map((GroupMember m) => m.userId), <String>['u1']);
  });

  test('leaving uses the signed-in user id', () async {
    final FakeGroupGateway gateway = FakeGroupGateway();
    final MembersController controller = MembersController(
      groupId: 'g1',
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);
    await controller.load();

    expect(await controller.leave(), isTrue);

    expect(gateway.left, <String>['u1']);
  });

  test('an owner can dissolve the group', () async {
    final FakeGroupGateway gateway = FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.owner),
        GroupMember(userId: 'u2', displayName: 'Maria', role: GroupRole.editor),
      ],
    );
    final MembersController controller = MembersController(
      groupId: 'g1',
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);
    await controller.load();

    expect(await controller.deleteGroup(), isTrue);

    expect(gateway.deleted, <String>['g1']);
    expect(controller.state.members, isEmpty);
  });

  test('a failed dissolution leaves the roster and reports it', () async {
    final FakeGroupGateway gateway = FakeGroupGateway()
      ..deleteError = Exception('offline');
    final MembersController controller = MembersController(
      groupId: 'g1',
      gateway: gateway,
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);
    await controller.load();

    expect(await controller.deleteGroup(), isFalse);

    expect(gateway.deleted, isEmpty);
    expect(controller.state.error, isNotNull);
  });

  test('with no backend it is idle', () async {
    final MembersController controller = MembersController(groupId: 'g1');
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.members, isEmpty);
  });
}
