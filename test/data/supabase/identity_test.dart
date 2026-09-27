import 'dart:convert';

import 'package:eatapp/data/supabase/identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

void main() {
  group('SupabaseIdentityGateway', () {
    test('a device that never signed in reports no identity', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final gateway = _gateway(await SharedPreferences.getInstance());

      expect(await gateway.current(), isNull);
    });

    test(
      'a stored session is restored as an identity without a network call',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          identityPrefsKey: jsonEncode(_sessionJson(userId: 'u-123')),
        });
        final gateway = _gateway(await SharedPreferences.getInstance());

        final Identity? identity = await gateway.current();
        expect(identity, isNotNull);
        expect(identity!.userId, 'u-123');
        expect(identity.isSignedIn, isTrue);
      },
    );

    test('a corrupt stored blob is dropped, not fatal', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        identityPrefsKey: 'not json at all',
      });
      final SharedPreferences preferences = await SharedPreferences
          .getInstance();
      final gateway = _gateway(preferences);

      expect(await gateway.current(), isNull);
      expect(
        preferences.containsKey(identityPrefsKey),
        isFalse,
        reason: 'the corrupt blob is removed so a later sign-in starts clean',
      );
    });

    test('signOut clears both the memory and the stored session', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        identityPrefsKey: jsonEncode(_sessionJson(userId: 'u-123')),
      });
      final SharedPreferences preferences = await SharedPreferences
          .getInstance();
      final gateway = _gateway(preferences);
      expect(await gateway.current(), isNotNull);

      await gateway.signOut();

      expect(await gateway.current(), isNull);
      expect(preferences.containsKey(identityPrefsKey), isFalse);
    });
  });
}

SupabaseIdentityGateway _gateway(SharedPreferences preferences) =>
    SupabaseIdentityGateway(
      // Never touched in these tests: every path here either reads the stored
      // session or only clears local state. A test that signs in for real
      // needs the live project, which is what supabase/tests covers instead.
      client: SupabaseClient('https://example.supabase.co', 'anon-key'),
      preferences: preferences,
    );

/// The smallest `Session.toJson()`-shaped map gotrue produces, with only the
/// fields `Session.fromJson` requires.
Map<String, dynamic> _sessionJson({required String userId}) =>
    <String, dynamic>{
      'access_token': 'at',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': 4102444800,
      'refresh_token': 'rt',
      'user': <String, dynamic>{
        'id': userId,
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{'provider': 'anonymous'},
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'role': 'authenticated',
      },
    };
