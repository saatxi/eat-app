package com.saatxi.eatapp.ui.model

import com.saatxi.eatapp.data.local.Restaurant

/** Stars the rating scale is drawn on. */
const val MAX_RATING = 5

/** Widest price range the source data can hold, so "$$$$" is the longest label. */
private const val MAX_PRICE_RANGE = 4

/**
 * What the screens draw, kept separate from the Room [Restaurant] entity so the
 * presentation decisions — the "$$" price string — are made once here instead
 * of being repeated inside composables.
 *
 * Anything that needs a string resource (the cuisine label, the "3/5" rating
 * text) stays in the composables: resolving those needs a Context, which the
 * ViewModel deliberately doesn't have. The cuisine is therefore carried as its
 * raw vocabulary key and resolved at draw time by `CuisineVisuals`.
 *
 * Every property is a primitive or a String on purpose. Compose infers
 * stability structurally, and a single `List` property here would mark the
 * whole class unstable — which would make every row of the list unskippable and
 * recompose the lot on any state change.
 */
data class RestaurantUiModel(
    val id: Long,
    val name: String,
    val cuisineKey: String,
    /** Null when the row has no address, so the screens can just skip the block. */
    val address: String?,
    val rating: Int,
    /** For example "$$". Empty when the row has no price range. */
    val priceLabel: String,
    /** False marks a place the user still wants to try, not one they've been to. */
    val visited: Boolean,
    /** Validated on import; null when absent or not safe to open. */
    val website: String?,
    /** Bare handle, no leading `@`. */
    val instagram: String?,
    val isFavorite: Boolean,
    /** Absolute path to a locally-stored copy; null draws the cuisine badge instead. */
    val photoPath: String? = null,
    /** Free-text, user-written. Null when blank, so the detail screen can just skip the card. */
    val notes: String? = null,
    /**
     * Comma-and-space-joined tag names, e.g. `"Terraza, Para grupos"`; empty
     * when there are none. A `List<String>` property here would make this
     * whole class Compose-unstable — see the class doc above — so screens
     * split this back apart (`tagsLabel.split(", ")`) at render time instead
     * of it ever being stored as a list. Tag names are validated (see
     * `normalizeTagName`) to never contain a comma, so the split is safe.
     */
    val tagsLabel: String = ""
) {
    /** True when there is at least one link worth drawing a section for. */
    val hasLinks: Boolean get() = website != null || instagram != null
}

fun Restaurant.toUiModel(isFavorite: Boolean = false, tags: List<String> = emptyList()): RestaurantUiModel = RestaurantUiModel(
    id = id,
    name = name,
    cuisineKey = cuisineType,
    // A row whose address is present but blank would otherwise draw an empty
    // location line; treat it the same as a missing one.
    address = address?.takeIf { it.isNotBlank() },
    rating = rating,
    // The reader already rejects out-of-range values, but clamping keeps a
    // hand-built entity from producing an absurdly long chip.
    priceLabel = "$".repeat(priceRange.coerceIn(0, MAX_PRICE_RANGE)),
    visited = visited,
    website = website,
    instagram = instagram,
    isFavorite = isFavorite,
    photoPath = photoPath,
    notes = notes?.takeIf { it.isNotBlank() },
    tagsLabel = tags.joinToString(", ")
)
