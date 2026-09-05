package com.saatxi.eatapp.data.local

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "restaurants",
    indices = [Index(value = ["name"]), Index(value = ["rating"])]
)
data class Restaurant(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val name: String,
    val cuisineType: String,
    val address: String?,
    val rating: Int,
    val priceRange: Int,
    /**
     * True once the user has actually been — false marks a place they still
     * want to try. Defaults true so a hand-built entity (tests, older data
     * paths) keeps today's implicit behaviour instead of silently becoming a
     * wishlist entry.
     */
    val visited: Boolean = true,
    /**
     * Optional links. Both are validated on import (see `LinkValidation.kt`) and
     * are null whenever the source `.db` omits the column, leaves it empty, or
     * holds something that isn't safe to open — the detail screen simply doesn't
     * draw a link it doesn't have.
     */
    val website: String? = null,
    /** Bare handle, no leading `@` and never a URL. */
    val instagram: String? = null,
    /**
     * Absolute path to a copy this app made of a user-picked photo, under its own
     * `filesDir/photos/` (see `RestaurantPhotoStorage.kt`) — never a `content://`
     * Uri handed back by the system Photo Picker, whose read grant is not
     * guaranteed to outlive this process. Null means no photo, which is also
     * what a restaurant received via import/share starts with: photos are
     * deliberately not part of that file format (see `RestaurantExport`).
     */
    val photoPath: String? = null,
    /**
     * Accent-stripped, lowercased concatenation of every searchable field.
     * Derived by default so it can never drift from the fields it mirrors; see
     * [buildSearchText].
     */
    val searchText: String = buildSearchText(name, cuisineType, address)
)
