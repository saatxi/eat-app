import 'package:diacritic/diacritic.dart';

/// Folds text the way both the stored `searchText` column and the search query
/// are folded: lowercase, accents stripped.
///
/// SQLite's `LIKE` only folds case for ASCII and never folds accents, so
/// searching "Mediterranea" would otherwise never match "Mediterránea" — which
/// is exactly the kind of text this data holds. Folding on both sides at write
/// time keeps the query itself a plain `LIKE`.
String normalizeForSearch(String text) => removeDiacritics(text).toLowerCase();

/// The normalized haystack stored alongside each row, covering every field the
/// search box matches against. Derived at write time so it can never drift
/// from the fields it mirrors.
String buildSearchText({
  required String name,
  required String cuisineType,
  String? streetAddress,
  String? city,
  String? region,
  String? country,
}) => normalizeForSearch(
  <String?>[
    name,
    cuisineType,
    streetAddress,
    city,
    region,
    country,
  ].whereType<String>().join(' '),
);

/// Escapes `LIKE` metacharacters (`%`, `_`, and the escape character itself)
/// so a typed query is matched literally rather than as a `LIKE` pattern.
/// Pairs with the `ESCAPE '\'` clause in [RestaurantDao.observeFiltered].
String escapeLikeWildcards(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll('%', r'\%')
    .replaceAll('_', r'\_');
