/// The rules a free-form tag has to satisfy, in one place.
///
/// Both the edit form's chip entry and the import of an untrusted file go
/// through here, so a tag that reaches the database is always one this file
/// would accept.
library;

/// Widest a single tag name can be before it's rejected rather than truncated.
const int maxTagNameLength = 40;

/// Caps how many tags one restaurant can carry — mainly a bound on junk from an
/// untrusted import file.
const int maxTagsPerRestaurant = 20;

/// Trims [raw] and rejects it outright (rather than silently stripping) when
/// it's empty, absurdly long, or contains a comma.
///
/// The comma ban is what keeps a comma-joined encoding of the tag list
/// unambiguous to split back apart — see the tag chips on the list and detail
/// screens, which join with `", "` and split on the same.
String? normalizeTagName(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty ||
      trimmed.length > maxTagNameLength ||
      trimmed.contains(',')) {
    return null;
  }
  return trimmed;
}

/// Validates a whole list the way an untrusted row is validated: a name that's
/// blank, too long or comma-carrying is dropped rather than failing the list,
/// duplicates fold together case-insensitively (the database's unique index is
/// `COLLATE NOCASE`, so "Terraza" and "terraza" are the same tag), and the
/// result is capped so one bad row can't create unbounded junk.
List<String> normalizeTagNames(Iterable<String> raw) {
  final List<String> names = <String>[];
  final Set<String> seen = <String>{};
  for (final String candidate in raw) {
    final String? name = normalizeTagName(candidate);
    if (name != null && seen.add(name.toLowerCase())) {
      names.add(name);
    }
  }
  return names.take(maxTagsPerRestaurant).toList();
}
