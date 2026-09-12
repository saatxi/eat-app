package com.saatxi.eatapp.data.local

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * One visit to a [Restaurant]: when, how it rated, and any free-text note about
 * that specific visit. A restaurant with zero [Visit] rows is a "want to try"
 * entry; one is "visited". Cascades on delete when its restaurant is removed.
 */
@Entity(
    tableName = "visits",
    foreignKeys = [
        ForeignKey(
            entity = Restaurant::class,
            parentColumns = ["id"],
            childColumns = ["restaurantId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index(value = ["restaurantId"])]
)
data class Visit(
    @PrimaryKey
    val id: String,
    val restaurantId: String,
    /** Epoch millis. */
    val visitDate: Long,
    /** 0-5. */
    val rating: Int,
    val notes: String? = null,
    /** Price level on this particular visit (0-4, same scale as [Restaurant.priceRange]); 0 means "not set". */
    val priceRange: Int = 0
)
