import 'package:eatapp/data/supabase/identity.dart';

/// A hand-written [IdentityGateway] fake — no mocking package, per the
/// project's convention.
///
/// It simulates the pieces of Supabase auth the app actually touches: a device
/// either has an identity or it does not, [signInWithProvider] mints one
/// (reusing the same user id on later calls, as the real backend does when the
/// same provider account signs in again), and [signOut] forgets it.
class FakeIdentityGateway implements IdentityGateway {
  FakeIdentityGateway({this.existingUserId});

  /// Pre-set as if a session had been restored from disk; null means "this
  /// device has never signed in".
  String? existingUserId;

  /// The provider passed to the last [signInWithProvider], for assertions.
  SocialProvider? lastProvider;

  /// How many times [signInWithProvider] ran.
  int signInCount = 0;

  /// The user id a provider sign-in mints, when the device had none.
  String providerUserId = 'fake-user-1';

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
  Future<Identity> signInWithProvider(SocialProvider provider) async {
    final Object? error = signInError;
    if (error != null) {
      throw error;
    }
    signInCount++;
    lastProvider = provider;
    existingUserId ??= providerUserId;
    return Identity(userId: existingUserId!, isSignedIn: true);
  }

  @override
  Future<Identity?> completeSignIn(Uri redirect) async => current();

  @override
  Future<void> signOut() async {
    existingUserId = null;
  }
}
