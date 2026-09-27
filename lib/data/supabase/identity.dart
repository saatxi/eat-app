import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

/// The app's remote identity, as the sync layer and the group features see it.
///
/// Deliberately narrower than `supabase`'s `Session`: the rest of the app must
/// not learn what a JWT is. [userId] is the stable identifier every
/// `createdBy` column and every `group_members` row will carry; [isSignedIn]
/// says whether a session exists at all (it does not vouch for the token still
/// being valid — the sync layer discovers that on its first request).
class Identity {
  const Identity({required this.userId, required this.isSignedIn});

  /// The Supabase `auth.users` id — a UUID string.
  final String userId;

  /// Whether a session exists on this device.
  final bool isSignedIn;
}

/// Everything the app needs from the remote identity provider, and nothing
/// more.
///
/// The concrete implementation wraps the `supabase` package; tests supply a
/// hand-written fake. Kept this narrow so the sync layer (phase 4) can be
/// written against it without dragging gotrue's types into every test.
abstract class IdentityGateway {
  /// The current identity, or null when this device has never signed in.
  Future<Identity?> current();

  /// Signs in anonymously — Supabase creates the `auth.users` row on the
  /// first call and simply issues a new session on every later one, so this
  /// is idempotent from the app's point of view.
  Future<Identity> signInAnonymously();

  /// Attaches an email to the anonymous account, so the identity survives a
  /// phone change. Optional by design: the app works fully without it.
  Future<void> linkEmail(String email);

  /// Forgets the session on this device. The remote `auth.users` row stays —
  /// signing in again anonymously mints a *new* identity, which is why this
  /// is only wired to an explicit "sign out" action, never called silently.
  Future<void> signOut();
}

/// Preference keys the gateway owns. Exposed so tests can pre-seed or assert
/// on exactly what was written.
const String identityPrefsKey = 'identity.supabase.session';

/// The real [IdentityGateway], over the `supabase` client.
///
/// The session is persisted as its JSON form under [identityPrefsKey] in the
/// same `SharedPreferences` file the rest of the app's preferences live in —
/// one store, no extra plugin. `SupabaseClient` itself keeps nothing on disk,
/// which is why the restore happens in the constructor's [_restore] step,
/// before anything can ask for [IdentityGateway.current].
class SupabaseIdentityGateway implements IdentityGateway {
  SupabaseIdentityGateway({
    required SupabaseClient client,
    required SharedPreferences preferences,
  // Private named fields cannot take initializing formals (Dart has no
  // private named parameters), so the assignments stay explicit.
  // ignore: prefer_initializing_formals
  }) : _client = client,
       // ignore: prefer_initializing_formals
       _preferences = preferences {
    _restore();
  }

  final SupabaseClient _client;
  final SharedPreferences _preferences;

  /// Restored at construction, so [current] never has to touch disk.
  Session? _restoredSession;

  void _restore() {
    final String? stored = _preferences.getString(identityPrefsKey);
    if (stored == null) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(stored);
      if (decoded is! Map) {
        throw const FormatException('not a JSON object');
      }
      _restoredSession = Session.fromJson(decoded.cast<String, dynamic>());
    } on FormatException {
      // A corrupt blob must never block the app from starting: drop it and
      // let the next sign-in mint a fresh session.
      _preferences.remove(identityPrefsKey);
      _restoredSession = null;
    }
  }

  @override
  Future<Identity?> current() async {
    final Session? session = _restoredSession;
    if (session == null) {
      return null;
    }
    return Identity(userId: session.user.id, isSignedIn: true);
  }

  @override
  Future<Identity> signInAnonymously() async {
    final AuthResponse response = await _client.auth.signInAnonymously();
    final Session? session = response.session;
    if (session == null) {
      throw const IdentityException('anonymous sign-in returned no session');
    }
    await _store(session);
    return Identity(userId: session.user.id, isSignedIn: true);
  }

  @override
  Future<void> linkEmail(String email) =>
      _client.auth.updateUser(UserAttributes(email: email));

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _restoredSession = null;
    await _preferences.remove(identityPrefsKey);
  }

  Future<void> _store(Session session) async {
    _restoredSession = session;
    await _preferences.setString(
      identityPrefsKey,
      jsonEncode(session.toJson()),
    );
  }
}

/// Something went wrong talking to the identity provider, in terms the app
/// can show a user.
class IdentityException implements Exception {
  const IdentityException(this.message);

  final String message;

  @override
  String toString() => 'IdentityException: $message';
}
