import 'package:eatapp/data/supabase/identity.dart';

/// A hand-written [IdentityGateway] fake — no mocking package, per the
/// project's convention.
///
/// It simulates the pieces of Supabase auth the app actually touches: a device
/// either has an identity or it does not, [verifyEmailCode] mints one (reusing
/// the same user id on later calls, as the real backend does when the same
/// address signs in again), and [signOut] forgets it.
class FakeIdentityGateway implements IdentityGateway {
  FakeIdentityGateway({this.existingUserId});

  /// Pre-set as if a session had been restored from disk; null means "this
  /// device has never signed in".
  String? existingUserId;

  /// The last email passed to [sendEmailCode] or [verifyEmailCode].
  String? lastEmail;

  /// The last code passed to [verifyEmailCode].
  String? lastCode;

  /// How many codes were sent.
  int sendCodeCount = 0;

  /// How many codes were verified (and so how many times a session was minted).
  int signInCount = 0;

  /// The user id a verified code mints, when the device had none.
  String providerUserId = 'fake-user-1';

  /// Throw to simulate a network/auth failure when sending or verifying.
  Object? sendError;
  Object? verifyError;

  @override
  Future<Identity?> current() async {
    final String? userId = existingUserId;
    if (userId == null) {
      return null;
    }
    return Identity(userId: userId, isSignedIn: true);
  }

  @override
  Future<void> sendEmailCode(String email) async {
    final Object? error = sendError;
    if (error != null) {
      throw error;
    }
    sendCodeCount++;
    lastEmail = email;
  }

  @override
  Future<Identity> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final Object? error = verifyError;
    if (error != null) {
      throw error;
    }
    signInCount++;
    lastEmail = email;
    lastCode = code;
    existingUserId ??= providerUserId;
    return Identity(userId: existingUserId!, isSignedIn: true);
  }

  @override
  Future<void> signOut() async {
    existingUserId = null;
  }
}
