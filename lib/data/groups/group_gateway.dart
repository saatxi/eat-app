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
  ///
  /// The backend does this atomically: both the groups row and the caller's
  /// owner membership land together, so if the owner-group cap (see
  /// [ownerGroupLimit]) refuses the membership, the whole creation rolls back
  /// and no orphan group is left behind. Throws a [GroupLimitException] when
  /// the caller already owns the configured maximum.
  Future<Group> createGroup({
    required String id,
    required String name,
  });

  /// The maximum number of groups one user may own, per the backend's
  /// `private.app_settings`. The UI uses it to disable the create action
  /// before anyone types a name; the backend is still the authority.
  Future<int> ownerGroupLimit();

  /// Edits the group's name. Only an owner may call this; RLS enforces it
  /// server-side via the `groups_update_owner` policy.
  Future<void> editGroup(String groupId, String name);

  /// The groups [userId] belongs to, each with their role.
  Future<List<Group>> listGroups(String userId);

  /// Every member of [groupId], with display names where they exist.
  Future<List<GroupMember>> listMembers(String groupId);

  /// Removes [userId]'s own membership — the caller leaves the group.
  Future<void> leaveGroup(String groupId, String userId);

  /// Removes [userId]'s membership — an owner expels a member.
  Future<void> removeMember(String groupId, String userId);

  /// Dissolves the group entirely. Only an owner may call this; the delete
  /// cascades every member, invite and shared row away. There is no undo, which
  /// is why the members screen offers an export first.
  Future<void> deleteGroup(String groupId);

  /// Creates or replaces [userId]'s own profile display name, so the rest of
  /// their groups see a name instead of a bare user id. The caller sets only
  /// their own name — `profiles_upsert_own` enforces that server-side.
  Future<void> setDisplayName({
    required String userId,
    required String displayName,
  });
}

/// The real [GroupGateway], over the Supabase client.
class SupabaseGroupGateway implements GroupGateway {
  SupabaseGroupGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Group> createGroup({
    required String id,
    required String name,
  }) async {
    // One transaction on the server: groups row + owner membership. The owner
    // cap trigger lives inside it, so a refused membership rolls the group row
    // back too — the old two-insert flow could leave an orphan group the
    // caller (not yet an owner, so RLS protects it) could not delete.
    try {
      await _client.rpc(
        'create_owned_group',
        params: <String, dynamic>{
          'p_id': id,
          'p_name': name,
        },
      );
    } on PostgrestException catch (error) {
      // Matched on the SQLSTATE the cap trigger raises, not its message, so a
      // reworded error cannot silently turn this into a generic failure.
      if (error.code == ownerGroupLimitReachedCode) {
        throw GroupLimitException(await ownerGroupLimit());
      }
      rethrow;
    }
    return Group(id: id, name: name, role: GroupRole.owner);
  }

  @override
  Future<int> ownerGroupLimit() async {
    final Object? value = await _client.rpc('owner_group_limit');
    return value is int ? value : 10;
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
    // The roster and the names are fetched separately: `group_members.user_id`
    // and `profiles.id` both reference `auth.users` rather than each other, so
    // PostgREST cannot embed one in the other — an embedded select fails
    // outright with "could not find a relationship between 'group_members' and
    // 'profiles'". The two row sets are joined in `groupMembersFromRows`.
    final List<Map<String, dynamic>> memberships =
        (await _client
                .from('group_members')
                .select('user_id, role')
                .eq('group_id', groupId))
            .cast<Map<String, dynamic>>();
    final List<String> ids = <String>[
      for (final Map<String, dynamic> row in memberships)
        row['user_id'] as String,
    ];
    final List<Map<String, dynamic>> profiles = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : (await _client
                  .from('profiles')
                  .select('id, display_name')
                  .inFilter('id', ids))
              .cast<Map<String, dynamic>>();
    return groupMembersFromRows(memberships: memberships, profiles: profiles);
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

  @override
  Future<void> editGroup(String groupId, String name) async {
    // Allowed by the groups_update_owner RLS policy.
    await _client.from('groups').update(<String, dynamic>{'name': name}).eq(
      'id',
      groupId,
    );
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    // Allowed by the groups_delete_owner policy; the foreign keys cascade every
    // member, invite and shared row. The last-owner guard trigger never fires
    // here, since the whole group goes at once.
    await _client.from('groups').delete().eq('id', groupId);
  }

  @override
  Future<void> setDisplayName({
    required String userId,
    required String displayName,
  }) async {
    // `profiles_upsert_own` allows the insert and `profiles_update_own` the
    // update, so one upsert covers a first-time name and a later change alike.
    await _client.from('profiles').upsert(<String, dynamic>{
      'id': userId,
      'display_name': displayName,
    });
  }
}

/// Parses one `group_members` row embedded with its group, as
/// `select('group_id, role, groups(name)')` returns it.
Group groupFromMembershipJson(Map<String, dynamic> json) => Group(
  id: json['group_id'] as String,
  name: (json['groups'] as Map<String, dynamic>)['name'] as String,
  role: GroupRole.fromRemote(json['role'] as String),
);

/// Merges a `group_members` roster with the `profiles` that name its users.
///
/// `group_members.user_id` and `profiles.id` both reference `auth.users`, not
/// each other, so PostgREST cannot embed the profile in the membership; the two
/// row sets are fetched separately and joined here. A member who never set a
/// display name has no `profiles` row, so `displayName` falls back to empty.
List<GroupMember> groupMembersFromRows({
  required List<Map<String, dynamic>> memberships,
  required List<Map<String, dynamic>> profiles,
}) {
  final Map<String, String> names = <String, String>{
    for (final Map<String, dynamic> profile in profiles)
      profile['id'] as String: (profile['display_name'] as String?) ?? '',
  };
  return <GroupMember>[
    for (final Map<String, dynamic> row in memberships)
      GroupMember(
        userId: row['user_id'] as String,
        displayName: names[row['user_id']] ?? '',
        role: GroupRole.fromRemote(row['role'] as String),
      ),
  ];
}
