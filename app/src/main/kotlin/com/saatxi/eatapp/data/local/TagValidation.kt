package com.saatxi.eatapp.data.local

/** Widest a single tag name can be before it's rejected rather than truncated. */
private const val MAX_TAG_NAME_LENGTH = 40

/** Caps how many tags one restaurant can carry — mainly a bound on junk from an untrusted import file. */
const val MAX_TAGS_PER_RESTAURANT = 20

/**
 * Trims [raw] and rejects it outright (rather than silently stripping) when
 * it's empty, absurdly long, or contains a comma — the comma ban keeps
 * `RestaurantUiModel.tagsLabel`'s comma-joined encoding unambiguous to split
 * back apart. Used by both the edit form's chip entry and import validation.
 */
fun normalizeTagName(raw: String): String? {
    val trimmed = raw.trim()
    if (trimmed.isEmpty() || trimmed.length > MAX_TAG_NAME_LENGTH || trimmed.contains(",")) return null
    return trimmed
}
