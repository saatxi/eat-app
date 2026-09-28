/// The invitation vocabulary the client exchanges with the groups backend.
///
/// Invitations are minted and redeemed exclusively by the `create-invite` and
/// `join-group` Edge Functions (see `supabase/functions/`): the client never
/// touches the `invites` table, and the raw token only ever exists on the
/// device that showed it and the one that typed it in.
library;

/// A freshly minted invitation, exactly as `create-invite` returns it.
///
/// [token] is shown once and never again — the remote stores only its SHA-256
/// hash — so the screen must keep this object for as long as the user might
/// copy the link or let someone scan the QR.
class Invite {
  const Invite({
    required this.token,
    required this.expiresAt,
    required this.maxUses,
  });

  /// The raw invitation token (16 characters from a no-ambiguity alphabet).
  final String token;

  /// When the invitation stops being redeemable.
  final DateTime expiresAt;

  /// How many times it may be redeemed in total.
  final int maxUses;
}

/// The group a token redeemed into, as `join-group` reports it.
class JoinedGroup {
  const JoinedGroup({required this.groupId, required this.groupName});

  final String groupId;
  final String groupName;
}

/// Why an invitation operation failed, in terms the UI can turn into a message.
///
/// The values mirror the `error` strings the Edge Functions return; [network]
/// is the client-side catch-all for a request that never reached the server.
enum InviteFailure {
  /// The request body was malformed — a client bug, not a user mistake.
  invalidRequest,

  /// No session could be established before the call.
  unauthenticated,

  /// Only an owner may mint invitations.
  notOwner,

  /// Too many join attempts in too short a window.
  rateLimited,

  /// Unknown, expired or exhausted token.
  inviteNotFound,

  /// The caller is already a member of the group.
  alreadyMember,

  /// An unexpected server failure.
  internal,

  /// The request never reached the server (offline, DNS, TLS...).
  network,
}

/// A failed invitation operation, carrying the reason the UI acts on.
class InviteException implements Exception {
  const InviteException(this.failure, [this.message]);

  final InviteFailure failure;
  final String? message;

  @override
  String toString() =>
      'InviteException($failure${message == null ? '' : ': $message'})';
}
