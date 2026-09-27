import 'package:supabase/supabase.dart';

import 'group_models.dart';

/// Everything the groups feature needs from the remote, and nothing more.
///
/// The real implementation wraps the Supabase client; tests supply a
/// hand-written fake, the same pattern as
/// [`IdentityGateway`](../supabase/identity.dart) and the sync transport.
/// Operations that act on "me" ([createGroup], [listGroups], [leaveGroup])
/// take the caller's user id explicitly rather than reading it from the
/// session, which keeps the gateway stateless and the fake trivial — the
/// caller already holds the identity and hands it over.
abstract class GroupGateway {
  /// Creates a group and joins the caller as its owner.
  Future<Group> createGroup({
    required String id,
    required String name,
    required String createdBy,
  });

  /// The groups [userId] belongs to, each with their role.
  Future<List<Group>> listGroups(String userId);

  /// Every member of [groupId], with display names where they exist.
  Future<List<GroupMember>> listMembers(String groupId);

  /// Removes [userId]'s own membership — the caller leaves the group.
  Future<void> leaveGroup(String groupId, String userId);

  /// Removes [userId]'s membership — an owner expels a member.
  Future<void> removeMember(String groupId, String userId);
}

/// The real [GroupGateway], over the Supabase client.
class SupabaseGroupGateway implements GroupGateway {
  SupabaseGroupGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Group> createGroup({
    required String id,
    required String name,
    required String createdBy,
  }) async {
    await _client.from('groups').insert(<String, dynamic>{
      'id': id,
      'name': name,
      'created_by': createdBy,
    });
    // The bootstrap membership: the creator joins as owner, allowed by the
    // `group_members_insert_owner` policy's creator case.
    await _client.from('group_members').insert(<String, dynamic>{
      'group_id': id,
      'user_id': createdBy,
      'role': GroupRole.owner.remote,
    });
    return Group(id: id, name: name, role: GroupRole.owner);
  }

  @override
  Future<List<Group>> listGroups(String userId) async {
    final memberships = await _client
        .from('group_members')
        .select('group_id, role, groups(name)')
        .eq('user_id', userId);
    return <Group>[
      for (final Map<String, dynamic> row in memberships)
        groupFromMembershipJson(row),
    ];
  }

  @override
  Future<List<GroupMember>> listMembers(String groupId) async {
    final rows = await _client
        .from('group_members')
        .select('user_id, role, profiles(display_name)')
        .eq('group_id', groupId);
    return <GroupMember>[
      for (final Map<String, dynamic> row in rows) groupMemberFromJson(row),
    ];
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }
}

/// Parses one `group_members` row embedded with its group, as
/// `select('group_id, role, groups(name)')` returns it.
Group groupFromMembershipJson(Map<String, dynamic> json) => Group(
  id: json['group_id'] as String,
  name: (json['groups'] as Map<String, dynamic>)['name'] as String,
  role: GroupRole.fromRemote(json['role'] as String),
);

/// Parses one `group_members` row embedded with its profile, as
/// `select('user_id, role, profiles(display_name)')` returns it. A member who
/// never set a display name has no `profiles` row, so `display_name` falls
/// back to empty.
GroupMember groupMemberFromJson(Map<String, dynamic> json) => GroupMember(
  userId: json['user_id'] as String,
  displayName: ((json['profiles'] as Map?) ?? const <String, dynamic>{})[
          'display_name'] as String? ??
      '',
  role: GroupRole.fromRemote(json['role'] as String),
);
