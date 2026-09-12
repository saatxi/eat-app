package com.saatxi.eatapp.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * A restaurant's own, place-level facts. Per-visit data (rating, notes, date)
 * lives in [Visit]; whether a place has been visited at all is derived from
 * whether it has any [Visit] rows, not stored here.
 */
@Entity(
    tableName = "restaurants",
    indices = [Index(value = ["name"])]
)
data class Restaurant(
    /** Client-generated UUID string, assigned by the repository at insert time — never Room autoincrement. */
    @PrimaryKey
    val id: String,
    val name: String,
    val cuisineType: String,
    /**
     * Street line only — town/region/country live in [city]/[region]/[country]. The physical
     * column stays named `address` (via [ColumnInfo]) for historical continuity with earlier schemas.
     */
    @ColumnInfo(name = "address")
    val streetAddress: String? = null,
    /** General price level of the place (0-4) — not per-visit. */
    val priceRange: Int,
    /**
     * Optional links. Both are validated on import (see `LinkValidation.kt`) and
     * are null whenever the source data omits the column, leaves it empty, or
     * holds something that isn't safe to open — the detail screen simply doesn't
     * draw a link it doesn't have.
     */
    val website: String? = null,
    /** Bare handle, no leading `@` and never a URL. */
    val instagram: String? = null,
    /** Town/city ("poble"). Free text with autocomplete over existing values — no closed vocabulary, unlike [cuisineType]. */
    val city: String? = null,
    /** State/province ("regió"). Same free-text-with-autocomplete treatment as [city]. */
    val region: String? = null,
    /** Country ("país"). Same free-text-with-autocomplete treatment as [city]. */
    val country: String? = null,
    /** Optional pin position for the Map screen (F-89) — null until the user sets it manually on the edit form. */
    val latitude: Double? = null,
    val longitude: Double? = null,
    /**
     * Accent-stripped, lowercased concatenation of every searchable field.
     * Derived by default so it can never drift from the fields it mirrors; see
     * [buildSearchText].
     */
    val searchText: String = buildSearchText(name, cuisineType, streetAddress, city, region, country)
)
