import 'package:eatapp/data/groups/group_gateway.dart';
import 'package:eatapp/data/groups/group_models.dart';

/// A hand-written [GroupGateway] fake — no mocking package, per the project's
/// convention.
class FakeGroupGateway implements GroupGateway {
  FakeGroupGateway({this.groups = const <Group>[]});

  List<Group> groups;

  /// The groups [createGroup] minted, for assertions.
  final List<Group> created = <Group>[];

  @override
  Future<Group> createGroup({
    required String id,
    required String name,
  }) async {
    final Group group = Group(id: id, name: name, role: GroupRole.owner);
    groups = <Group>[...groups, group];
    created.add(group);
    return group;
  }

  @override
  Future<int> ownerGroupLimit() async => 2;

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
  Future<void> setRole(String groupId, String userId, GroupRole role) async {}

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
