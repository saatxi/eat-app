/// The invitation link's shape, in one place: how it is built, and how a link,
/// a QR payload or a hand-typed code is turned back into a token.
///
/// Two forms are accepted on the way in — the app's own custom scheme
/// (`eatapp://join/<token>`, what the QR and the share carry, and what the
/// Android intent-filter and the iOS URL scheme are registered for) and an
/// `https://<host>/join/<token>` path, ready for the day an App Link / Universal
/// Link publishes one. A bare alphanumeric code is accepted too: that is the
/// fallback a user reads out loud or types by hand.
library;

/// The custom URL scheme the app owns (`android:scheme` / `CFBundleURLSchemes`).
const String inviteScheme = 'eatapp';

/// The host, and also the path segment of the `https` form, that marks a link
/// as a join link rather than any other deep link the app might grow.
const String inviteJoinHost = 'join';

/// The token alphabet the `create-invite` Edge Function draws from: base32-ish
/// with `I`, `L`, `O`, `0` and `1` removed, so a hand-typed code has no
/// look-alike characters.
const String inviteTokenAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// The token length `create-invite` mints (128 bits, one character per byte
/// modulo the alphabet).
const int inviteTokenLength = 32;

/// The deep link the QR encodes and the share sheet carries.
String inviteLink(String token) => Uri(
  scheme: inviteScheme,
  host: inviteJoinHost,
  pathSegments: <String>[token],
).toString();

/// The token inside [uri], or null when it is not a join link at all.
///
/// Handles both registered forms; a link that isn't ours (or carries a
/// malformed token) returns null so the caller can ignore it rather than open
/// the join screen on nonsense.
String? inviteTokenFromUri(Uri uri) {
  if (uri.scheme == inviteScheme && uri.host == inviteJoinHost) {
    return normaliseInviteToken(
      uri.pathSegments.isEmpty ? null : uri.pathSegments.first,
    );
  }
  final List<String> segments = uri.pathSegments;
  if (segments.length == 2 && segments.first == inviteJoinHost) {
    return normaliseInviteToken(segments[1]);
  }
  return null;
}

/// The token named by [text], whether that is a full link, a scanned QR payload
/// or a bare code. Null when nothing usable is in there.
String? inviteTokenFromText(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final Uri? uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    final String? fromUri = inviteTokenFromUri(uri);
    if (fromUri != null) {
      return fromUri;
    }
  }
  return normaliseInviteToken(trimmed);
}

/// Upper-cases [raw] and checks it against the token alphabet, or returns null.
///
/// Trims outer whitespace and uppercases first, so a code copied with a stray
/// space or typed in lower case still resolves.
String? normaliseInviteToken(String? raw) {
  if (raw == null) {
    return null;
  }
  final String token = raw.trim().toUpperCase();
  if (token.length != inviteTokenLength) {
    return null;
  }
  for (final int unit in token.codeUnits) {
    if (!inviteTokenAlphabet.codeUnits.contains(unit)) {
      return null;
    }
  }
  return token;
}
