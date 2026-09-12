package com.saatxi.eatapp.ui.model

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.Visit
import com.saatxi.eatapp.data.local.formatAddress

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
 * [rating]/[visited]/[notes] now come from the restaurant's latest [Visit]
 * (there's at most one, in this pass's single-visit-per-restaurant UI) rather
 * than from the restaurant entity itself — see `toUiModel`.
 */
data class RestaurantUiModel(
    val id: String,
    val name: String,
    val cuisineKey: String,
    /** Street line only — null when absent/blank. See [formattedAddress] for the joined display string. */
    val streetAddress: String?,
    val city: String?,
    val region: String?,
    val country: String?,
    /** Pin position for the Map screen (F-89); null when the user hasn't set one. */
    val latitude: Double? = null,
    val longitude: Double? = null,
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
    /** Free-text, user-written note from the latest visit. Null when blank, so the detail screen can just skip the card. */
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

    /** Every non-blank address component joined together — see [com.saatxi.eatapp.data.local.formatAddress]. */
    val formattedAddress: String? get() = formatAddress(streetAddress, city, region, country)
}

fun Restaurant.toUiModel(
    isFavorite: Boolean = false,
    tags: List<String> = emptyList(),
    latestVisit: Visit? = null,
    photoPath: String? = null
): RestaurantUiModel = RestaurantUiModel(
    id = id,
    name = name,
    cuisineKey = cuisineType,
    // A row whose address component is present but blank would otherwise draw
    // an empty location line; treat it the same as a missing one.
    streetAddress = streetAddress?.takeIf { it.isNotBlank() },
    city = city?.takeIf { it.isNotBlank() },
    region = region?.takeIf { it.isNotBlank() },
    country = country?.takeIf { it.isNotBlank() },
    latitude = latitude,
    longitude = longitude,
    rating = latestVisit?.rating ?: 0,
    // The reader already rejects out-of-range values, but clamping keeps a
    // hand-built entity from producing an absurdly long chip.
    priceLabel = "$".repeat(priceRange.coerceIn(0, MAX_PRICE_RANGE)),
    visited = latestVisit != null,
    website = website,
    instagram = instagram,
    isFavorite = isFavorite,
    photoPath = photoPath,
    notes = latestVisit?.notes?.takeIf { it.isNotBlank() },
    tagsLabel = tags.joinToString(", ")
)
