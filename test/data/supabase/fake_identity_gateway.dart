import 'package:eatapp/data/supabase/identity.dart';

/// A hand-written [IdentityGateway] fake — no mocking package, per the
/// project's convention.
///
/// It simulates the pieces of Supabase auth the app actually touches: a
/// device either has an identity or it does not, `signInAnonymously` mints
/// one (reusing the same user id on later calls, as the real backend does for
/// repeat anonymous sign-ins from a restored session), and `signOut` forgets
/// it. The email link is recorded, not sent.
class FakeIdentityGateway implements IdentityGateway {
  FakeIdentityGateway({this.existingUserId});

  /// Pre-set as if a session had been restored from disk; null means "this
  /// device has never signed in".
  String? existingUserId;

  /// The last email passed to [linkEmail], for assertions.
  String? linkedEmail;

  /// How many times [signInAnonymously] ran.
  int signInCount = 0;

  /// Throw to simulate a network/auth failure.
  Object? signInError;

  @override
  Future<Identity?> current() async {
    final String? userId = existingUserId;
    if (userId == null) {
      return null;
    }
    return Identity(userId: userId, isSignedIn: true);
  }

  @override
  Future<Identity> signInAnonymously() async {
    final Object? error = signInError;
    if (error != null) {
      throw error;
    }
    signInCount++;
    existingUserId ??= 'fake-user-$signInCount';
    return Identity(userId: existingUserId!, isSignedIn: true);
  }

  @override
  Future<void> linkEmail(String email) async {
    linkedEmail = email;
  }

  @override
  Future<void> signOut() async {
    existingUserId = null;
    linkedEmail = null;
  }
}
