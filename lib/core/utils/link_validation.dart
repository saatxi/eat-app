/// Validation for the two optional link fields of a restaurant.
///
/// These values end up in a platform "open this URL" call, so an unvalidated
/// value could otherwise hand the system a `javascript:`, `intent:` or `file:`
/// URI and have it act on that. Everything here is a whitelist: a value that
/// isn't recognisably safe becomes null rather than being passed through.
///
/// Deliberately free of any Flutter or platform import so the rules are plain
/// Dart, testable on their own.
library;

/// Schemes the app is willing to hand to the system browser.
const Set<String> allowedWebSchemes = <String>{'http', 'https'};

final RegExp _schemePrefix = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:');

/// Instagram's own rules: letters, digits, periods and underscores, up to 30
/// characters. Constraining the handle this tightly is what makes scheme
/// injection structurally impossible — the URL is built *from* it, never parsed
/// out of user input.
final RegExp _instagramHandle = RegExp(r'^[A-Za-z0-9._]{1,30}$');

/// Base for [instagramUrl]; the handle is appended verbatim after validation.
const String _instagramBaseUrl = 'https://instagram.com/';

/// Normalizes a website value, or returns null if it isn't a plain web URL.
///
/// A value with no scheme at all is assumed to be `https://` — people tend to
/// type a bare host like `example.com`, and refusing those would be pedantry
/// rather than safety.
String? normalizeWebsite(String? raw) {
  final String value = raw?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }

  final RegExpMatch? match = _schemePrefix.firstMatch(value);
  if (match == null) {
    return 'https://$value';
  }

  final String scheme = match.group(0)!.toLowerCase();
  return allowedWebSchemes.contains(scheme.substring(0, scheme.length - 1))
      ? value
      : null;
}

/// Normalizes an Instagram value to a bare handle, or returns null.
///
/// Accepts the handle with or without a leading `@`, which is how people write
/// it. A full URL is rejected: storing the handle keeps the app in control of
/// the URL it eventually opens.
String? normalizeInstagramHandle(String? raw) {
  String handle = raw?.trim() ?? '';
  if (handle.startsWith('@')) {
    handle = handle.substring(1);
  }
  return _instagramHandle.hasMatch(handle) ? handle : null;
}

/// The profile URL for a handle already validated by [normalizeInstagramHandle].
String instagramUrl(String handle) => '$_instagramBaseUrl$handle';
