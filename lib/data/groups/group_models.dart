/// The shared-groups vocabulary, as the client sees it.
///
/// The groups themselves live only on the remote (Supabase `groups` /
/// `group_members`); the drift database holds the restaurants they sync, not
/// the roster. These models are what the groups feature reads and writes
/// through the [GroupGateway].
library;

/// A member's role, mirroring the `group_members.role` column's two values.
enum GroupRole {
  owner,
  member;

  /// The value the column stores: the enum's own name (`owner` / `member`).
  String get remote => name;

  /// Parses a stored role. An unknown value (only possible if a role is added
  /// remotely before the app learns it) fails loudly rather than guessing.
  static GroupRole fromRemote(String value) => switch (value) {
    'owner' => GroupRole.owner,
    'member' => GroupRole.member,
    _ => throw GroupException('unrecognised group role: $value'),
  };
}

/// A group the signed-in user belongs to, as the group selector shows it.
class Group {
  const Group({required this.id, required this.name, required this.role});

  final String id;
  final String name;

  /// The signed-in user's role in this group.
  final GroupRole role;
}

/// One member of a group, as the members screen shows it.
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;

  /// Empty when the member never set a display name.
  final String displayName;
  final GroupRole role;
}

/// Something went wrong talking to the groups backend, in terms the app can
/// log or show.
class GroupException implements Exception {
  const GroupException(this.message);

  final String message;

  @override
  String toString() => 'GroupException: $message';
}

/// The signed-in user already owns the configured maximum number of groups, so
/// the backend refused a new `create_owned_group` call. Distinct from a plain
/// [GroupException] so the UI can say exactly this instead of a generic
/// failure.
class GroupLimitException implements GroupException {
  const GroupLimitException(this.limit);

  /// The number of owned groups allowed.
  final int limit;

  @override
  String get message => 'owner_group_limit_reached (limit $limit)';

  @override
  String toString() => 'GroupLimitException: $message';
}
