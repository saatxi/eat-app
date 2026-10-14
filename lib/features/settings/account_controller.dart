import 'package:flutter/foundation.dart';

import '../../data/supabase/identity.dart';
import '../groups/groups_controller.dart';

@immutable
class AccountState {
  const AccountState({this.busy = false, this.signedIn = false});

  final bool busy;
  final bool signedIn;
}

/// Manages whether the user is signed in and drives the create/delete account
/// actions, decoupling the identity side-effects from the Settings widget tree.
class AccountController extends ChangeNotifier {
  AccountController({required this.identity, this.groups});

  final IdentityGateway identity;
  final GroupsController? groups;

  AccountState _state = const AccountState();
  AccountState get state => _state;

  Future<void> refresh() async {
    final Identity? me = await identity.current();
    _update(signedIn: me != null);
  }

  /// Mints a new account and signs in. Returns true on success, false on failure.
  Future<bool> createAccount() async {
    _update(busy: true);
    try {
      await identity.createAccount();
      await groups?.load();
      return true;
    } on Object {
      return false;
    } finally {
      _update(busy: false);
      await refresh();
    }
  }

  /// Erases the account. Returns true on success, false on failure.
  Future<bool> deleteAccount() async {
    _update(busy: true);
    try {
      await identity.deleteAccount();
      await groups?.load();
      return true;
    } on Object {
      return false;
    } finally {
      _update(busy: false);
      await refresh();
    }
  }

  void _update({bool? busy, bool? signedIn}) {
    _state = AccountState(
      busy: busy ?? _state.busy,
      signedIn: signedIn ?? _state.signedIn,
    );
    notifyListeners();
  }
}
