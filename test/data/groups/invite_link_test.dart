import 'package:eatapp/data/groups/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// A valid token: 16 characters, all from the no-ambiguity alphabet — the
/// shape the backend mints (128 bits, one character per byte).
const String _token = 'ABCDEFGHJKMNPQRS'; // 16 chars, all in the alphabet.

void main() {
  test('builds the custom-scheme link', () {
    expect(inviteLink(_token), 'eatapp://join/$_token');
  });

  test('round-trips a link back to its token', () {
    expect(inviteTokenFromUri(Uri.parse(inviteLink(_token))), _token);
  });

  test('parses the future https form', () {
    expect(
      inviteTokenFromUri(Uri.parse('https://eat.example/join/$_token')),
      _token,
    );
  });

  test('ignores a link that is not a join link', () {
    expect(inviteTokenFromUri(Uri.parse('eatapp://widget/abc')), isNull);
    expect(
      inviteTokenFromUri(Uri.parse('https://eat.example/other/$_token')),
      isNull,
    );
  });

  test('ignores a malformed token in an otherwise valid link', () {
    expect(inviteTokenFromUri(Uri.parse('eatapp://join/short')), isNull);
    // Right length, but '0' is not in the alphabet.
    expect(inviteTokenFromUri(Uri.parse('eatapp://join/${'0' * 16}')), isNull);
  });

  test('normalises a hand-typed code', () {
    expect(inviteTokenFromText('  ${_token.toLowerCase()}  '), _token);
  });

  test('accepts either a bare code or a whole link', () {
    expect(inviteTokenFromText(_token), _token);
    expect(inviteTokenFromText(inviteLink(_token)), _token);
    expect(
      inviteTokenFromText('https://eat.example/join/$_token'),
      _token,
    );
  });

  test('returns null for empty or unusable text', () {
    expect(inviteTokenFromText(''), isNull);
    expect(inviteTokenFromText('   '), isNull);
    expect(inviteTokenFromText('not a code'), isNull);
    expect(normaliseInviteToken(null), isNull);
  });
}
