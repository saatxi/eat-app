import 'package:eatapp/data/groups/group_gateway.dart';
import 'package:eatapp/data/groups/group_models.dart';

/// A hand-written [GroupGateway] fake — no mocking package, per the project's
/// convention.
///
/// Covers every controller's needs in one place: failure injection for
/// [createGroup]/[listGroups] ([error]), [deleteGroup] ([deleteError]) and
/// [setDisplayName] ([nameError]); and recording which users left, were
/// removed, or were renamed, and which groups were created or dissolved.
class FakeGroupGateway implements GroupGateway {
  FakeGroupGateway({
    this.groups = const <Group>[],
    this.members = const <GroupMember>[],
  });

  List<Group> groups;
  List<GroupMember> members;

  /// Throw to simulate a backend failure on [createGroup] or [listGroups].
  Object? error;

  /// Throw to simulate a backend failure on [deleteGroup].
  Object? deleteError;

  /// Throw to simulate a backend failure on [setDisplayName].
  Object? nameError;

  /// The groups [createGroup] minted, for assertions.
  final List<Group> created = <Group>[];

  /// The users whose leave went through, for assertions.
  final List<String> left = <String>[];

  /// The users an owner removed, for assertions.
  final List<String> removed = <String>[];

  /// The groups dissolved through [deleteGroup] (or by the last member
  /// leaving), for assertions.
  final List<String> deleted = <String>[];

  /// The display names [setDisplayName] stored, keyed by user id.
  final Map<String, String> names = <String, String>{};

  /// The names [editGroup] stored, keyed by group id.
  final Map<String, String> renamed = <String, String>{};

  @override
  Future<Group> createGroup({
    required String id,
    required String name,
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
  Future<List<GroupMember>> listMembers(String groupId) async => members;

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
      deleted.add(groupId);
      groups = <Group>[
        for (final Group group in groups)
          if (group.id != groupId) group,
      ];
    }
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    removed.add(userId);
    members = <GroupMember>[
      for (final GroupMember member in members)
        if (member.userId != userId) member,
    ];
  }

  @override
  Future<void> setRole(String groupId, String userId, GroupRole role) async {}

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
  Future<void> deleteGroup(String groupId) async {
    final Object? failure = deleteError;
    if (failure != null) {
      throw failure;
    }
    deleted.add(groupId);
    members = const <GroupMember>[];
  }

  @override
  Future<void> setDisplayName({
    required String userId,
    required String displayName,
  }) async {
    final Object? failure = nameError;
    if (failure != null) {
      throw failure;
    }
    names[userId] = displayName;
    members = <GroupMember>[
      for (final GroupMember member in members)
        if (member.userId == userId)
          GroupMember(
            userId: member.userId,
            displayName: displayName,
            role: member.role,
          )
        else
          member,
    ];
  }
}
