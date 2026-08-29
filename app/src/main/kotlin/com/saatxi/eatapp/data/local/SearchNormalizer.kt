package com.saatxi.eatapp.data.local

import java.text.Normalizer

private val COMBINING_MARKS = Regex("\\p{Mn}+")

/**
 * Folds text the way both [Restaurant.searchText] and the search query are
 * folded: lowercase, accents stripped.
 *
 * SQLite's `LIKE` only folds case for ASCII and never folds accents, so
 * searching "Mediterranea" would otherwise never match "Mediterránea" — which
 * is exactly the kind of text this data holds. Normalizing on both sides at
 * import time keeps the query itself a plain `LIKE`.
 */
fun normalizeForSearch(text: String): String =
    COMBINING_MARKS
        .replace(Normalizer.normalize(text, Normalizer.Form.NFD), "")
        .lowercase()

/**
 * The normalized haystack stored alongside each row, covering every field the
 * search box matches against.
 */
fun buildSearchText(
    name: String,
    cuisineType: String,
    address: String?
): String = normalizeForSearch(
    listOfNotNull(name, cuisineType, address).joinToString(" ")
)

/**
 * Escapes `LIKE` metacharacters (`%`, `_`, and the escape character itself)
 * so a typed query is matched literally rather than as a `LIKE` pattern.
 * Pairs with the `ESCAPE '\'` clause in [RestaurantDao.observeFiltered].
 */
fun escapeLikeWildcards(text: String): String =
    text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
