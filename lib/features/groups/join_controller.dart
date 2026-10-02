import 'package:flutter/foundation.dart';

import '../../data/groups/invite_gateway.dart';
import '../../data/groups/invite_models.dart';
import '../../data/supabase/identity.dart';

/// The joining-side invitation flow: redeem a token the user scanned, pasted or
/// typed, with the display name they want the group to know them by.
@immutable
class JoinState {
  const JoinState({
    this.isJoining = false,
    this.joined,
    this.failure,
    this.message,
  });

  final bool isJoining;

  /// The group the last successful join landed in, so the screen can hand the
  /// caller its id to select.
  final JoinedGroup? joined;

  /// Why the last attempt failed, for the UI to phrase. Null before the first
  /// attempt and after a success.
  final InviteFailure? failure;
  final String? message;
}

/// Redeems an invitation token, signing the device in anonymously first when it
/// has never signed in — a join needs a caller identity.
///
/// A null [gateway] leaves [canJoin] false and any attempt a no-op, so the
/// screen still builds in a bare test or a build with no backend.
class JoinController extends ChangeNotifier {
  JoinController({this.gateway, this.identity});

  final InviteGateway? gateway;
  final IdentityGateway? identity;

  JoinState _state = const JoinState();
  bool _disposed = false;

  JoinState get state => _state;
  bool get canJoin => gateway != null;

  /// Redeems [token] as [displayName]. Returns whether it worked; the outcome
  /// is also published on [state].
  Future<bool> join({
    required String token,
    required String displayName,
  }) async {
    final InviteGateway? invites = gateway;
    if (invites == null) {
      return false;
    }
    _set(const JoinState(isJoining: true));
    try {
      await _ensureSignedIn();
      final JoinedGroup joined = await invites.joinGroup(
        token: token,
        displayName: displayName,
      );
      _set(JoinState(joined: joined));
      return true;
    } on InviteException catch (error) {
      _set(JoinState(failure: error.failure, message: error.message));
      return false;
    } catch (error) {
      _set(JoinState(failure: InviteFailure.network, message: error.toString()));
      return false;
    }
  }

  /// Clears the last outcome, e.g. after the screen has acted on a failure.
  void reset() => _set(const JoinState());

  /// Signs in with [provider], for the screen to offer before a first join.
  /// Returns whether it worked.
  Future<bool> signIn(SocialProvider provider) async {
    final IdentityGateway? account = identity;
    if (account == null) {
      return false;
    }
    try {
      await account.signInWithProvider(provider);
      return true;
    } catch (error) {
      _set(JoinState(failure: InviteFailure.network, message: error.toString()));
      return false;
    }
  }

  Future<void> _ensureSignedIn() async {
    final IdentityGateway? account = identity;
    if (account == null) {
      return;
    }
    if (await account.current() != null) {
      return;
    }
    // Sign-in is a deliberate, visible step now; a join without a session fails
    // here rather than silently minting a throwaway identity that could never
    // be recovered after a reinstall.
    throw const InviteException(InviteFailure.unauthenticated);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _set(JoinState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}
