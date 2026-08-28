package com.albertferran.eatapp.data.local

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
     * Optional links. Both are validated on import (see `LinkValidation.kt`) and
     * are null whenever the source `.db` omits the column, leaves it empty, or
     * holds something that isn't safe to open — the detail screen simply doesn't
     * draw a link it doesn't have.
     */
    val website: String? = null,
    /** Bare handle, no leading `@` and never a URL. */
    val instagram: String? = null,
    /**
     * Accent-stripped, lowercased concatenation of every searchable field.
     * Derived by default so it can never drift from the fields it mirrors; see
     * [buildSearchText].
     */
    val searchText: String = buildSearchText(name, cuisineType, address)
)
