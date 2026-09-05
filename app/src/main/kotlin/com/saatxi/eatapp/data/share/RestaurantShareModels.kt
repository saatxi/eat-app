package com.saatxi.eatapp.data.share

import com.saatxi.eatapp.data.local.MAX_TAGS_PER_RESTAURANT
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.normalizeInstagramHandle
import com.saatxi.eatapp.data.local.normalizeTagName
import com.saatxi.eatapp.data.local.normalizeWebsite
import kotlinx.serialization.Serializable

/**
 * On-the-wire shape of one restaurant in a share/export file. Never carries
 * [Restaurant.id] or [Restaurant.searchText] — the id is meaningless (or
 * worse, colliding) once the row lands in someone else's database, and the
 * search text is derived, not data.
 */
@Serializable
data class RestaurantExport(
    val name: String,
    val cuisineType: String,
    val address: String? = null,
    val rating: Int,
    val priceRange: Int,
    // Defaults true so a file written before this field existed still imports
    // as "visited" — today's only mode until now — rather than as a wishlist
    // entry no one asked for.
    val visited: Boolean = true,
    val website: String? = null,
    val instagram: String? = null,
    // Defaults null so a file written before this field existed still imports
    // fine, just without a note — the same backward-compatibility treatment
    // `visited` got in F-55.
    val notes: String? = null,
    // Defaults empty for the same reason `notes` defaults null — a file
    // written before tags existed (F-59) still imports, just without any.
    val tags: List<String> = emptyList()
)

/**
 * Top-level shape of a shared/exported file. [format] is a cheap gate against
 * a same-extension file that happens to be valid JSON but isn't ours — the
 * app registers to open plain `.json` files, so this matters.
 */
@Serializable
data class RestaurantShareFile(
    val format: String = FORMAT,
    val restaurants: List<RestaurantExport>
) {
    companion object {
        const val FORMAT = "eatapp.restaurants.v1"
    }
}

// [tags] isn't a field on [Restaurant] itself — it lives in the RestaurantTag
// join table — so every caller has to look its restaurant's tags up and pass
// them in, rather than this being derivable from the entity alone.
fun Restaurant.toExport(tags: List<String> = emptyList()): RestaurantExport = RestaurantExport(
    name = name,
    cuisineType = cuisineType,
    address = address,
    rating = rating,
    priceRange = priceRange,
    visited = visited,
    website = website,
    instagram = instagram,
    notes = notes,
    tags = tags
)

/**
 * Validates one exported restaurant exactly like the add/edit form would —
 * this is untrusted input arriving from outside the app, the same way the
 * old synced `.db` was. Returns null — dropping just this row — rather than
 * failing the whole file, the same per-row leniency the old sync used for a
 * bad link column.
 *
 * Deliberately doesn't return the row's tags — see [ImportedRestaurant],
 * which pairs the [Restaurant] this produces with its own validated tags.
 */
fun RestaurantExport.toRestaurantOrNull(): Restaurant? {
    val trimmedName = name.trim()
    val trimmedCuisine = cuisineType.trim()
    if (trimmedName.isEmpty() || trimmedCuisine.isEmpty()) return null
    if (rating !in 0..5 || priceRange !in 0..4) return null

    return Restaurant(
        id = 0,
        name = trimmedName,
        cuisineType = trimmedCuisine,
        address = address?.trim()?.takeIf { it.isNotBlank() },
        rating = rating,
        priceRange = priceRange,
        visited = visited,
        website = website?.let(::normalizeWebsite),
        instagram = instagram?.let(::normalizeInstagramHandle),
        notes = notes?.trim()?.takeIf { it.isNotBlank() }
    )
}

/**
 * Validates the raw [RestaurantExport.tags] list the same per-item-lenient
 * way the rest of an import row is validated: a tag that's blank, too long,
 * or contains a comma is dropped rather than failing the row, duplicates
 * fold together case-insensitively, and the whole list is capped so one
 * malicious row can't create unbounded junk.
 */
fun RestaurantExport.toValidatedTagNames(): List<String> =
    tags.mapNotNull(::normalizeTagName).distinctBy { it.lowercase() }.take(MAX_TAGS_PER_RESTAURANT)
