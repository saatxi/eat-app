import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import 'account_code.dart';

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
/// There is no email and no password the user has to remember. The app holds a
/// random account code and hands it to the `adopt-account` Edge Function, which
/// derives a synthetic email/password from it; the app then signs in with the
/// ordinary password grant. [createAccount] mints a fresh code on first use,
/// [signInWithCode] adopts an existing one on another device, and [accountCode]
/// exposes the stored code so Settings can show it and a backup can carry it.
abstract class IdentityGateway {
  /// The current identity, or null when this device has never signed in.
  Future<Identity?> current();

  /// Mints a fresh account code, adopts it and signs in. The code is the whole
  /// identity; losing it loses the account.
  Future<Identity> createAccount();

  /// Adopts an existing [code] — typed by the user or read from a backup — and
  /// signs in, bringing that account's groups back.
  Future<Identity> signInWithCode(String code);

  /// The stored account code, or null when this device has never had one. Read
  /// by Settings and by an account backup; never sent anywhere but
  /// `adopt-account`.
  String? accountCode();

  /// Forgets the session on this device. The account itself, and its stored
  /// code, stay — signing in again with the same code restores the same
  /// identity and group ownership.
  Future<void> signOut();

  /// Erases the account: the profile, every group the user owns, and their
  /// memberships in other people's groups, then signs out. Irreversible.
  ///
  /// The remote erase runs in the `delete-account` Edge Function — removing the
  /// auth user needs the service role — while the local session and the
  /// now-meaningless account code are cleared here once it succeeds.
  Future<void> deleteAccount();
}

/// Preference keys the gateway owns. Exposed so tests can pre-seed or assert
/// on exactly what was written.
const String identityPrefsKey = 'identity.supabase.session';

/// Where the account code is kept. Survives [IdentityGateway.signOut] — it is
/// the identity, not the session.
const String accountCodePrefsKey = 'identity.account.code';

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
  String? accountCode() => _preferences.getString(accountCodePrefsKey);

  @override
  Future<Identity> createAccount() => _adopt(generateAccountCode());

  @override
  Future<Identity> signInWithCode(String code) async {
    final String normalized = normalizeAccountCode(code);
    if (!isValidAccountCode(normalized)) {
      throw const IdentityException('not a valid account code');
    }
    return _adopt(normalized);
  }

  /// Swaps [code] for credentials at `adopt-account`, signs in with them, and
  /// stores both the code and the resulting session.
  Future<Identity> _adopt(String code) async {
    final ({String email, String password}) credentials =
        await _credentialsFor(code);
    final AuthResponse response = await _client.auth.signInWithPassword(
      email: credentials.email,
      password: credentials.password,
    );
    final Session? session = response.session;
    if (session == null) {
      throw const IdentityException('sign-in produced no session');
    }
    await _preferences.setString(accountCodePrefsKey, code);
    await _store(session);
    return Identity(userId: session.user.id, isSignedIn: true);
  }

  /// Calls the `adopt-account` Edge Function for [code].
  ///
  /// The function is public (`verify_jwt` off): the caller has no session yet,
  /// which is the whole point. It derives the credentials from the code and
  /// returns them; the sign-in itself then happens here, so the session never
  /// leaves the device.
  Future<({String email, String password})> _credentialsFor(String code) async {
    final Object? data;
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'adopt-account',
        body: <String, dynamic>{'code': code},
      );
      if (response.status < 200 || response.status >= 300) {
        throw IdentityException(
          'adopt-account refused the code (${response.status})',
        );
      }
      data = response.data;
    } on IdentityException {
      rethrow;
    } on FunctionException catch (error) {
      throw IdentityException('adopt-account failed (${error.status})');
    } on Object catch (error) {
      throw IdentityException('adopt-account request failed: $error');
    }
    if (data is! Map) {
      throw const IdentityException('adopt-account returned no credentials');
    }
    final Object? email = data['email'];
    final Object? password = data['password'];
    if (email is! String || password is! String) {
      throw const IdentityException('adopt-account returned no credentials');
    }
    return (email: email, password: password);
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
    // The account code is deliberately kept: it is the identity, not the
    // session, and the user needs it back to sign in again.
  }

  @override
  Future<void> deleteAccount() async {
    await _invokeDeleteAccount();
    // The account is gone: drop the session and the now-meaningless code, so
    // the device returns to the never-signed-in state.
    try {
      await _client.auth.signOut();
    } on Object {
      // The server session went with the user; a failed round-trip must not
      // leave the device holding one.
    }
    _restoredSession = null;
    _pendingSessionJson = null;
    await _preferences.remove(identityPrefsKey);
    await _preferences.remove(accountCodePrefsKey);
  }

  /// Calls the `delete-account` Edge Function, which erases the server-side
  /// account. Throws [IdentityException] when it does not succeed, so the UI can
  /// keep the signed-in state and offer a retry.
  Future<void> _invokeDeleteAccount() async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'delete-account',
        body: const <String, dynamic>{},
      );
      if (response.status < 200 || response.status >= 300) {
        throw IdentityException('delete-account failed (${response.status})');
      }
    } on IdentityException {
      rethrow;
    } on FunctionException catch (error) {
      throw IdentityException('delete-account failed (${error.status})');
    } on Object catch (error) {
      throw IdentityException('delete-account request failed: $error');
    }
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
