import 'package:eatapp/data/groups/invite_gateway.dart';
import 'package:eatapp/data/groups/invite_models.dart';
import 'package:eatapp/data/supabase/identity.dart';
import 'package:eatapp/features/groups/invite_controller.dart';
import 'package:eatapp/features/groups/join_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/supabase/fake_identity_gateway.dart';

/// A valid token, so the controller tests exercise the same shapes the backend
/// mints rather than any string.
const String _token = 'ABCDEFGHJKMNPQRS'; // 16 chars, all in the alphabet.

/// A hand-written [InviteGateway] fake — no mocking package, per the project's
/// convention.
class _FakeInviteGateway implements InviteGateway {
  Invite invite = Invite(
    token: _token,
    expiresAt: DateTime.utc(2030),
    maxUses: 7,
  );
  JoinedGroup joined = const JoinedGroup(groupId: 'g1', groupName: 'Família');

  /// Throw to simulate a backend failure.
  Object? error;

  int createCalls = 0;
  String? lastToken;
  String? lastDisplayName;

  @override
  Future<Invite> createInvite({
    required String groupId,
    int maxUses = 10,
    int expiresInDays = 7,
  }) async {
    createCalls++;
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return invite;
  }

  @override
  Future<JoinedGroup> joinGroup({
    required String token,
    required String displayName,
  }) async {
    lastToken = token;
    lastDisplayName = displayName;
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return joined;
  }
}

void main() {
  group('InviteController', () {
    test('with no backend it can neither create nor hold one', () async {
      final InviteController controller = InviteController(groupId: 'g1');
      addTearDown(controller.dispose);

      expect(controller.canCreate, isFalse);
      expect(await controller.create(), isFalse);
      expect(controller.state.invite, isNull);
    });

    test('mints a token for the group', () async {
      final _FakeInviteGateway gateway = _FakeInviteGateway();
      final InviteController controller = InviteController(
        groupId: 'g1',
        gateway: gateway,
        identity: FakeIdentityGateway(existingUserId: 'u1'),
      );
      addTearDown(controller.dispose);

      expect(await controller.create(), isTrue);
      expect(controller.state.invite?.token, _token);
      expect(controller.state.error, isNull);
      expect(gateway.createCalls, 1);
    });

    test('fails without a session, asking the user to sign in', () async {
      final FakeIdentityGateway identity = FakeIdentityGateway();
      final InviteController controller = InviteController(
        groupId: 'g1',
        gateway: _FakeInviteGateway(),
        identity: identity,
      );
      addTearDown(controller.dispose);

      expect(await controller.create(), isFalse);
      expect(identity.signInCount, 0);
      expect(controller.state.error, isA<IdentityException>());
    });

    test('signIn delegates to the chosen provider', () async {
      final FakeIdentityGateway identity = FakeIdentityGateway();
      final InviteController controller = InviteController(
        groupId: 'g1',
        gateway: _FakeInviteGateway(),
        identity: identity,
      );
      addTearDown(controller.dispose);

      expect(await controller.signIn(SocialProvider.google), isTrue);
      expect(identity.signInCount, 1);
      expect(identity.lastProvider, SocialProvider.google);
    });

    test('surfaces a failure and keeps any earlier invite', () async {
      final _FakeInviteGateway gateway = _FakeInviteGateway();
      final InviteController controller = InviteController(
        groupId: 'g1',
        gateway: gateway,
        identity: FakeIdentityGateway(existingUserId: 'u1'),
      );
      addTearDown(controller.dispose);

      await controller.create();
      gateway.error = const InviteException(InviteFailure.notOwner);

      expect(await controller.create(), isFalse);
      expect(controller.state.error, isA<InviteException>());
      expect(controller.state.invite?.token, _token);
    });
  });

  group('JoinController', () {
    test('with no backend it cannot join', () async {
      final JoinController controller = JoinController();
      addTearDown(controller.dispose);

      expect(controller.canJoin, isFalse);
      expect(
        await controller.join(token: _token, displayName: 'Maria'),
        isFalse,
      );
    });

    test('redeems a token and reports the group', () async {
      final _FakeInviteGateway gateway = _FakeInviteGateway();
      final JoinController controller = JoinController(
        gateway: gateway,
        identity: FakeIdentityGateway(existingUserId: 'u1'),
      );
      addTearDown(controller.dispose);

      expect(
        await controller.join(token: _token, displayName: 'Maria'),
        isTrue,
      );
      expect(controller.state.joined?.groupId, 'g1');
      expect(gateway.lastToken, _token);
      expect(gateway.lastDisplayName, 'Maria');
    });

    test('fails without a session, asking the user to sign in first', () async {
      final FakeIdentityGateway identity = FakeIdentityGateway();
      final JoinController controller = JoinController(
        gateway: _FakeInviteGateway(),
        identity: identity,
      );
      addTearDown(controller.dispose);

      expect(
        await controller.join(token: _token, displayName: 'Maria'),
        isFalse,
      );
      expect(identity.signInCount, 0);
      expect(controller.state.failure, InviteFailure.unauthenticated);
    });

    test('maps a server failure onto its reason', () async {
      final _FakeInviteGateway gateway = _FakeInviteGateway()
        ..error = const InviteException(InviteFailure.inviteNotFound);
      final JoinController controller = JoinController(
        gateway: gateway,
        identity: FakeIdentityGateway(existingUserId: 'u1'),
      );
      addTearDown(controller.dispose);

      expect(
        await controller.join(token: _token, displayName: 'Maria'),
        isFalse,
      );
      expect(controller.state.failure, InviteFailure.inviteNotFound);
      expect(controller.state.joined, isNull);
    });

    test('an unexpected failure reads as a network problem', () async {
      final _FakeInviteGateway gateway = _FakeInviteGateway()
        ..error = Exception('socket');
      final JoinController controller = JoinController(
        gateway: gateway,
        identity: FakeIdentityGateway(existingUserId: 'u1'),
      );
      addTearDown(controller.dispose);

      await controller.join(token: _token, displayName: 'Maria');

      expect(controller.state.failure, InviteFailure.network);
    });
  });
}
