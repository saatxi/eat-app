import 'package:supabase/supabase.dart';

import 'invite_models.dart';

/// Everything the invitation feature needs from the remote, and nothing more.
///
/// Both operations go through Edge Functions rather than RLS: minting a token
/// and atomically redeeming one are server-authoritative by design (see
/// `supabase/functions/create-invite` and `.../join-group`). The real
/// implementation wraps the Supabase client's function invoker; tests supply a
/// hand-written fake, the same pattern as [GroupGateway].
abstract class InviteGateway {
  /// Mints an invitation for [groupId]. Only an owner may call this; the
  /// function enforces that server-side.
  Future<Invite> createInvite({
    required String groupId,
    int maxUses,
    int expiresInDays,
  });

  /// Redeems [token] for the signed-in caller, storing [displayName] on their
  /// profile along the way.
  Future<JoinedGroup> joinGroup({
    required String token,
    required String displayName,
  });
}

/// The real [InviteGateway], over the Supabase Edge Functions.
class SupabaseInviteGateway implements InviteGateway {
  SupabaseInviteGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Invite> createInvite({
    required String groupId,
    int maxUses = 10,
    int expiresInDays = 7,
  }) async {
    final Object? data = await _invoke('create-invite', <String, dynamic>{
      'groupId': groupId,
      'maxUses': maxUses,
      'expiresInDays': expiresInDays,
    });
    if (data is! Map) {
      throw const InviteException(InviteFailure.internal);
    }
    final Object? token = data['token'];
    final Object? expiresAt = data['expiresAt'];
    if (token is! String || expiresAt is! String) {
      throw _failureFromBody(data);
    }
    return Invite(
      token: token,
      expiresAt: DateTime.parse(expiresAt),
      maxUses: data['maxUses'] is int ? data['maxUses'] as int : maxUses,
    );
  }

  @override
  Future<JoinedGroup> joinGroup({
    required String token,
    required String displayName,
  }) async {
    final Object? data = await _invoke('join-group', <String, dynamic>{
      'token': token,
      'displayName': displayName,
    });
    if (data is! Map) {
      throw const InviteException(InviteFailure.internal);
    }
    final Object? groupId = data['groupId'];
    final Object? groupName = data['groupName'];
    if (groupId is! String || groupName is! String) {
      throw _failureFromBody(data);
    }
    return JoinedGroup(groupId: groupId, groupName: groupName);
  }

  /// Invokes [name] and normalises both failure shapes into an
  /// [InviteException]: a thrown [FunctionException] (a non-2xx status) and a
  /// transport error that never reached the function at all.
  Future<Object?> _invoke(String name, Map<String, dynamic> body) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        name,
        body: body,
      );
      // Some client versions return the error body through a non-2xx status
      // rather than throwing; both are handled here.
      if (response.status < 200 || response.status >= 300) {
        throw _failureFromBody(response.data);
      }
      return response.data;
    } on InviteException {
      rethrow;
    } on FunctionException catch (error) {
      throw _failureFromBody(error.details);
    } on Object catch (error) {
      throw InviteException(InviteFailure.network, error.toString());
    }
  }
}

/// Maps the `{ "error": "..." }` body the Edge Functions return onto an
/// [InviteException]. An unknown or missing tag reads as [InviteFailure.internal]
/// — the server failed in a way the client doesn't have words for.
InviteException _failureFromBody(Object? body) {
  final Object? tag = body is Map ? body['error'] : null;
  return InviteException(_failureFromTag(tag), tag is String ? tag : null);
}

InviteFailure _failureFromTag(Object? tag) => switch (tag) {
  'invalid_request' => InviteFailure.invalidRequest,
  'unauthenticated' => InviteFailure.unauthenticated,
  'not_owner' => InviteFailure.notOwner,
  'rate_limited' => InviteFailure.rateLimited,
  'invite_not_found' => InviteFailure.inviteNotFound,
  'already_member' => InviteFailure.alreadyMember,
  _ => InviteFailure.internal,
};
