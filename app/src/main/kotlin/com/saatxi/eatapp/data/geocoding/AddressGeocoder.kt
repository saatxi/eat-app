package com.saatxi.eatapp.data.geocoding

/** A resolved lat/lng pair — see [AddressGeocoder.geocode]. */
data class GeocodeResult(val latitude: Double, val longitude: Double)

/**
 * Turns a free-text address into a lat/lng pair, for the edit form's
 * "look up coordinates" action (F-89) — an alternative to typing them in by
 * hand. Pulled out as an interface, the same reasoning as
 * [com.saatxi.eatapp.data.photo.RestaurantPhotoStorage]: `RestaurantEditViewModel`
 * can be unit tested against a fake instead of needing a real network call.
 */
fun interface AddressGeocoder {
    /** Null when [query] is blank, no match was found, or the lookup failed (offline, rate-limited, malformed response...). */
    suspend fun geocode(query: String): GeocodeResult?
}
