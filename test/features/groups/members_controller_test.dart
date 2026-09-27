import 'package:eatapp/data/groups/group_gateway.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/features/groups/members_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/supabase/fake_identity_gateway.dart';

/// A hand-written [GroupGateway] fake covering the membership calls.
class _FakeGroupGateway implements GroupGateway {
  _FakeGroupGateway({this.members = const <GroupMember>[]});

  List<GroupMember> members;
  final List<String> removed = <String>[];
  final List<String> left = <String>[];
  final List<String> deleted = <String>[];

  /// Throw to simulate a backend failure on [deleteGroup].
  Object? deleteError;

  @override
  Future<List<GroupMember>> listMembers(String groupId) async => members;

  @override
  Future<void> removeMember(String groupId, String userId) async {
    removed.add(userId);
    members = <GroupMember>[
      for (final GroupMember member in members)
        if (member.userId != userId) member,
    ];
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) async {
    left.add(userId);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    final Object? failure = deleteError;
    if (failure != null) {
      throw failure;
    }
    deleted.add(groupId);
    members = <GroupMember>[];
  }

  @override
  Future<Group> createGroup({
    required String id,
    required String name,
    required String createdBy,
  }) async => throw UnimplementedError();

  @override
  Future<List<Group>> listGroups(String userId) async => const <Group>[];
}

void main() {
  test('loads the roster and marks the current user', () async {
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.owner),
        GroupMember(userId: 'u2', displayName: 'Maria', role: GroupRole.member),
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
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.owner),
        GroupMember(userId: 'u2', displayName: 'Maria', role: GroupRole.member),
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
    final _FakeGroupGateway gateway = _FakeGroupGateway();
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
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Me', role: GroupRole.owner),
        GroupMember(userId: 'u2', displayName: 'Maria', role: GroupRole.member),
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
    final _FakeGroupGateway gateway = _FakeGroupGateway()
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
