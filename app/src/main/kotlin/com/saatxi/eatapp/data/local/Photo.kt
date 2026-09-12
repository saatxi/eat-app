package com.saatxi.eatapp.data.local

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * A stored photo, attached either to a [Restaurant] directly or to one of its
 * [Visit]s — exactly one of [restaurantId]/[visitId] should be non-null in
 * practice (enforced in the repository, not at the DB level). Cascades on
 * delete either way, so removing a restaurant or a visit cleans up its photos.
 */
@Entity(
    tableName = "photos",
    foreignKeys = [
        ForeignKey(
            entity = Restaurant::class,
            parentColumns = ["id"],
            childColumns = ["restaurantId"],
            onDelete = ForeignKey.CASCADE
        ),
        ForeignKey(
            entity = Visit::class,
            parentColumns = ["id"],
            childColumns = ["visitId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index(value = ["restaurantId"]), Index(value = ["visitId"])]
)
data class Photo(
    @PrimaryKey
    val id: String,
    val restaurantId: String? = null,
    val visitId: String? = null,
    /** Absolute path to a copy this app made under its own `filesDir/photos/` — see `RestaurantPhotoStorage.kt`. */
    val path: String,
    val position: Int = 0
)
