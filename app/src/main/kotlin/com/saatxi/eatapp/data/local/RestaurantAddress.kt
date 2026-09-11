package com.saatxi.eatapp.data.local

/**
 * Joins the non-blank address components into one display string (e.g. for the detail screen's
 * `geo:` Maps intent), or null when every component is blank/absent.
 */
fun formatAddress(streetAddress: String?, city: String?, region: String?, country: String?): String? =
    listOfNotNull(streetAddress, city, region, country)
        .map { it.trim() }
        .filter { it.isNotBlank() }
        .joinToString(", ")
        .takeIf { it.isNotBlank() }

fun Restaurant.formattedAddress(): String? = formatAddress(streetAddress, city, region, country)
