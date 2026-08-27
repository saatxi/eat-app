package com.albertferran.eatapp.data.local

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.time.LocalDate

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
    val notes: String,
    val visitDate: LocalDate,
    val photoUri: String?,
    val createdAt: Long,
    /**
     * Accent-stripped, lowercased concatenation of every searchable field.
     * Derived by default so it can never drift from the fields it mirrors; see
     * [buildSearchText].
     */
    val searchText: String = buildSearchText(name, cuisineType, address, notes)
)
