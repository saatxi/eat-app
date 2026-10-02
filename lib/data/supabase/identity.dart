import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

/// The app's remote identity, as the sync layer and the group features see it.
///
/// Deliberately narrower than `supabase`'s `Session`: the rest of the app must
/// not learn what a JWT is. [userId] is the stable identifier every
/// `createdBy` column and every `group_members` row carries; [isSignedIn]
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
/// Sign-in is by an email one-time code: [sendEmailCode] mails a short code and
/// [verifyEmailCode] exchanges it for a session. There is no password, no
/// browser and no redirect — the whole exchange happens inside the app, so the
/// behaviour is identical on Android and iOS and there is no custom URL
/// callback to keep in step between them. The verified email is the stable
/// identity, which is what makes ownership recoverable after a reinstall.
abstract class IdentityGateway {
  /// The current identity, or null when this device has never signed in.
  Future<Identity?> current();

  /// Emails a one-time sign-in code to [email]. Creates the account on first
  /// use, so the same address works on every device.
  Future<void> sendEmailCode(String email);

  /// Exchanges the code the user typed for a session, and returns the identity.
  Future<Identity> verifyEmailCode({
    required String email,
    required String code,
  });

  /// Forgets the session on this device. The remote `auth.users` row stays —
  /// signing in again with the same email recovers the same identity, which is
  /// what restores group ownership.
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
/// so [_restore] reads the JSON back in the constructor — but that only tells
/// the app who it is. The client stays unauthenticated until
/// [_ensureClientSession] hands the same JSON to the client's own
/// `recoverSession`, which every path that carries the session reaches through
/// [current].
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

  /// The stored JSON still to be handed to the client, or null once it has been
  /// recovered — or when there was nothing to recover. Kept as the raw string
  /// because the client's `recoverSession` takes the serialized session, not a
  /// `Session`.
  String? _pendingSessionJson;

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
      _pendingSessionJson = stored;
    } on FormatException {
      // A corrupt blob must never block the app from starting: drop it and
      // let the next sign-in mint a fresh session.
      _preferences.remove(identityPrefsKey);
      _restoredSession = null;
    }
  }

  @override
  Future<Identity?> current() async {
    if (_restoredSession == null) {
      return null;
    }
    // Re-establish the client's session before reporting an identity, since
    // every later request carries it.
    await _ensureClientSession();
    final Session? session = _restoredSession;
    if (session == null) {
      return null;
    }
    return Identity(userId: session.user.id, isSignedIn: true);
  }

  /// Hands the stored session to the client, once.
  ///
  /// The client is built fresh on every launch and keeps nothing on disk, so
  /// restoring the JSON into [_restoredSession] alone would leave its auth
  /// unauthenticated: every request it then makes — creating a group, syncing —
  /// would be anonymous and refused by row-level security. A token that can no
  /// longer be recovered (expired or revoked) is dropped here instead, so the
  /// next sign-in starts clean rather than the app carrying a dead one.
  Future<void> _ensureClientSession() async {
    final String? pending = _pendingSessionJson;
    if (pending == null) {
      return;
    }
    _pendingSessionJson = null;
    try {
      await _client.auth.recoverSession(pending);
    } on Object {
      _restoredSession = null;
      await _preferences.remove(identityPrefsKey);
    }
  }

  @override
  Future<void> sendEmailCode(String email) =>
      _client.auth.signInWithOtp(email: email, shouldCreateUser: true);

  @override
  Future<Identity> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final AuthResponse response = await _client.auth.verifyOTP(
      type: OtpType.email,
      email: email,
      token: code,
    );
    final Session? session = response.session;
    if (session == null) {
      throw const IdentityException('the code did not produce a session');
    }
    await _store(session);
    return Identity(userId: session.user.id, isSignedIn: true);
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on Object {
      // The client drops its own session before it reaches the server, so a
      // round-trip that cannot complete — offline, a server it can't reach —
      // must not leave this device still holding a session the client has
      // already forgotten.
    }
    _restoredSession = null;
    _pendingSessionJson = null;
    await _preferences.remove(identityPrefsKey);
  }

  Future<void> _store(Session session) async {
    _restoredSession = session;
    // The client already holds this session; nothing is left to recover.
    _pendingSessionJson = null;
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
