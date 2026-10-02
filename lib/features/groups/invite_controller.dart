import 'package:flutter/foundation.dart';

import '../../data/groups/invite_models.dart';
import '../../data/groups/invite_gateway.dart';
import '../../data/supabase/identity.dart';

/// The owner-side invitation flow: mint a token for one group and hold it while
/// the screen shows its QR and link.
@immutable
class InviteState {
  const InviteState({this.invite, this.isLoading = false, this.error});

  /// The last minted invitation, kept across a failed retry so a working QR is
  /// never blanked out by a later failure.
  final Invite? invite;

  final bool isLoading;
  final Object? error;
}

/// Mints an invitation for [groupId] on behalf of its owner and keeps the token
/// for the screen to render.
///
/// A null [gateway] (a build with no backend, or a bare test) leaves [canCreate]
/// false and every call a no-op, so the screen can be built without one.
class InviteController extends ChangeNotifier {
  InviteController({required this.groupId, this.gateway, this.identity});

  final String groupId;
  final InviteGateway? gateway;
  final IdentityGateway? identity;

  /// The number of redemptions a freshly minted invitation allows.
  static const int defaultMaxUses = 10;

  /// How long a freshly minted invitation stays valid.
  static const int defaultExpiresInDays = 7;

  InviteState _state = const InviteState();
  bool _disposed = false;

  InviteState get state => _state;
  bool get canCreate => gateway != null;

  /// Mints a fresh invitation. Returns whether it worked; a failure lands in
  /// [InviteState.error].
  Future<bool> create({
    int maxUses = defaultMaxUses,
    int expiresInDays = defaultExpiresInDays,
  }) async {
    final InviteGateway? invites = gateway;
    if (invites == null) {
      return false;
    }
    _set(InviteState(invite: _state.invite, isLoading: true));
    try {
      // The owner already signed in when the group was created, but a lapsed
      // session would otherwise fail here with a bare 401.
      await _ensureSignedIn();
      final Invite invite = await invites.createInvite(
        groupId: groupId,
        maxUses: maxUses,
        expiresInDays: expiresInDays,
      );
      _set(InviteState(invite: invite));
      return true;
    } catch (error) {
      _set(InviteState(invite: _state.invite, error: error));
      return false;
    }
  }

  Future<void> _ensureSignedIn() async {
    final IdentityGateway? account = identity;
    if (account == null) {
      return;
    }
    if (await account.current() == null) {
      throw const IdentityException('sign in required');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _set(InviteState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}
