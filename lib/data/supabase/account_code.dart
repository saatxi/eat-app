import 'dart:math';

/// The account code: the user's whole identity, as the app generates and reads
/// it.
///
/// Sign-in no longer uses email. The app holds this random code and hands it to
/// the `adopt-account` Edge Function, which derives a synthetic email and
/// password from it (see `supabase/functions/adopt-account`). The code is
/// therefore a bearer secret — anyone who has it can adopt the account — so it
/// carries ~80 bits of entropy and must be kept like a password.
///
/// The alphabet drops the ambiguous glyphs O, I, L, 0 and 1, so a code copied
/// by hand or read aloud is hard to get wrong. Kept in step with
/// `CODE_ALPHABET` / `CODE_LENGTH` in
/// `supabase/functions/adopt-account/index.ts`.
const String accountCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// How many characters a code has, before grouping.
const int accountCodeLength = 16;

/// How many characters sit between the hyphens when a code is displayed.
const int accountCodeGroupSize = 4;

/// The largest multiple of the alphabet length that fits in a byte (248 for 31
/// characters). Bytes at or above it are discarded rather than folded with a
/// modulo, which would make the first `256 % 31` characters likelier than the
/// rest — the same unbiased-sampling trick as the invitation token.
final int _unbiasedByteLimit =
    (256 ~/ accountCodeAlphabet.length) * accountCodeAlphabet.length;

/// A fresh account code of [accountCodeLength] characters, drawn from
/// [accountCodeAlphabet].
///
/// [random] exists for tests, which pass a seeded generator so a code is
/// reproducible; production always uses [Random.secure].
String generateAccountCode({Random? random}) {
  final Random source = random ?? Random.secure();
  final StringBuffer code = StringBuffer();
  while (code.length < accountCodeLength) {
    final int byte = source.nextInt(256);
    if (byte < _unbiasedByteLimit) {
      code.write(accountCodeAlphabet[byte % accountCodeAlphabet.length]);
    }
  }
  return code.toString();
}

/// Uppercases [raw] and drops every non-alphanumeric character, so a code the
/// user typed or pasted with spaces or hyphens matches the one that was
/// generated.
String normalizeAccountCode(String raw) =>
    raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

/// Whether [raw] normalizes to a well-formed code: the expected length, and
/// only characters from [accountCodeAlphabet].
bool isValidAccountCode(String raw) {
  final String code = normalizeAccountCode(raw);
  return code.length == accountCodeLength &&
      code.split('').every(accountCodeAlphabet.contains);
}

/// [raw] normalized and grouped with hyphens every [accountCodeGroupSize]
/// characters — the shape shown in Settings and written into a backup.
String formatAccountCode(String raw) {
  final String code = normalizeAccountCode(raw);
  final StringBuffer formatted = StringBuffer();
  for (int i = 0; i < code.length; i++) {
    if (i > 0 && i % accountCodeGroupSize == 0) {
      formatted.write('-');
    }
    formatted.write(code[i]);
  }
  return formatted.toString();
}

/// [raw] with its middle groups hidden, for the Settings row where the code is
/// shown at rest: `ABCD-••••-••••-WXYZ`. The full code stays available through
/// an explicit reveal or copy.
String maskAccountCode(String raw) {
  final String code = normalizeAccountCode(raw);
  if (code.length != accountCodeLength) {
    return formatAccountCode(raw);
  }
  // Built group by group rather than through [formatAccountCode]: that helper
  // normalizes, which would strip the mask's dots as non-alphanumerics.
  final List<String> groups = <String>[];
  for (int i = 0; i < code.length; i += accountCodeGroupSize) {
    final bool isEdge =
        i == 0 || i + accountCodeGroupSize == code.length;
    groups.add(
      isEdge
          ? code.substring(i, i + accountCodeGroupSize)
          : '•' * accountCodeGroupSize,
    );
  }
  return groups.join('-');
}
