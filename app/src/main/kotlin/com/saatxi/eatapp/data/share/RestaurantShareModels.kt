package com.saatxi.eatapp.data.share

import com.saatxi.eatapp.data.local.MAX_TAGS_PER_RESTAURANT
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.Visit
import com.saatxi.eatapp.data.local.normalizeInstagramHandle
import com.saatxi.eatapp.data.local.normalizeTagName
import com.saatxi.eatapp.data.local.normalizeWebsite
import kotlinx.serialization.Serializable

/** On-the-wire shape of one visit — see [Visit]. No id: it's meaningless once it lands in someone else's database. */
@Serializable
data class VisitExport(
    val visitDate: Long,
    val rating: Int,
    val notes: String? = null,
    /** 0-4, same scale as [RestaurantExport.priceRange]; 0 means "not set". Defaults to 0 so a v2-era file written before this field existed still imports cleanly. */
    val priceRange: Int = 0
)

/**
 * On-the-wire shape of one restaurant in a share/export file. Never carries
 * [Restaurant.id] or [Restaurant.searchText] — the id is meaningless (or
 * worse, colliding) once the row lands in someone else's database, and the
 * search text is derived, not data. Photos are deliberately excluded, same
 * as before.
 */
@Serializable
data class RestaurantExport(
    val name: String,
    val cuisineType: String,
    val streetAddress: String? = null,
    val priceRange: Int,
    val website: String? = null,
    val instagram: String? = null,
    val tags: List<String> = emptyList(),
    val city: String? = null,
    val region: String? = null,
    val country: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val visits: List<VisitExport> = emptyList()
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
        const val FORMAT = "eatapp.restaurants.v2"
    }
}

// [tags]/[visits] aren't fields on [Restaurant] itself — tags live in the
// RestaurantTag join table, visits in their own table — so every caller has
// to look them up and pass them in, rather than this being derivable from
// the entity alone.
fun Restaurant.toExport(tags: List<String> = emptyList(), visits: List<Visit> = emptyList()): RestaurantExport = RestaurantExport(
    name = name,
    cuisineType = cuisineType,
    streetAddress = streetAddress,
    priceRange = priceRange,
    website = website,
    instagram = instagram,
    tags = tags,
    city = city,
    region = region,
    country = country,
    latitude = latitude,
    longitude = longitude,
    visits = visits.map { VisitExport(visitDate = it.visitDate, rating = it.rating, notes = it.notes, priceRange = it.priceRange) }
)

/**
 * Validates one exported restaurant exactly like the add/edit form would —
 * this is untrusted input arriving from outside the app. Returns null —
 * dropping just this row — rather than failing the whole file.
 *
 * Deliberately doesn't return an id: the caller assigns a fresh UUID, and
 * doesn't return tags/visits either — see [ImportedRestaurant] for those.
 */
fun RestaurantExport.toRestaurantOrNull(id: String): Restaurant? {
    val trimmedName = name.trim()
    val trimmedCuisine = cuisineType.trim()
    if (trimmedName.isEmpty() || trimmedCuisine.isEmpty()) return null
    if (priceRange !in 0..4) return null
    if (latitude != null && latitude !in -90.0..90.0) return null
    if (longitude != null && longitude !in -180.0..180.0) return null
    if (visits.any { it.rating !in 0..5 || it.priceRange !in 0..4 }) return null

    return Restaurant(
        id = id,
        name = trimmedName,
        cuisineType = trimmedCuisine,
        streetAddress = streetAddress?.trim()?.takeIf { it.isNotBlank() },
        priceRange = priceRange,
        website = website?.let(::normalizeWebsite),
        instagram = instagram?.let(::normalizeInstagramHandle),
        city = city?.trim()?.takeIf { it.isNotBlank() },
        region = region?.trim()?.takeIf { it.isNotBlank() },
        country = country?.trim()?.takeIf { it.isNotBlank() },
        latitude = latitude,
        longitude = longitude
    )
}

/** The row's visits, dropping any that individually fail validation rather than failing the whole row. */
fun RestaurantExport.toValidatedVisits(): List<VisitExport> = visits.filter { it.rating in 0..5 && it.priceRange in 0..4 }

/**
 * Validates the raw [RestaurantExport.tags] list the same per-item-lenient
 * way the rest of an import row is validated: a tag that's blank, too long,
 * or contains a comma is dropped rather than failing the row, duplicates
 * fold together case-insensitively, and the whole list is capped so one
 * malicious row can't create unbounded junk.
 */
fun RestaurantExport.toValidatedTagNames(): List<String> =
    tags.mapNotNull(::normalizeTagName).distinctBy { it.lowercase() }.take(MAX_TAGS_PER_RESTAURANT)
