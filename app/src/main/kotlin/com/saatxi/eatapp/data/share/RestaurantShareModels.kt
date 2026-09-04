package com.saatxi.eatapp.data.share

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.normalizeInstagramHandle
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
    val instagram: String? = null
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

fun Restaurant.toExport(): RestaurantExport = RestaurantExport(
    name = name,
    cuisineType = cuisineType,
    address = address,
    rating = rating,
    priceRange = priceRange,
    visited = visited,
    website = website,
    instagram = instagram
)

/**
 * Validates one exported restaurant exactly like the add/edit form would —
 * this is untrusted input arriving from outside the app, the same way the
 * old synced `.db` was. Returns null — dropping just this row — rather than
 * failing the whole file, the same per-row leniency the old sync used for a
 * bad link column.
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
        instagram = instagram?.let(::normalizeInstagramHandle)
    )
}
