package com.saatxi.eatapp.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * A free-form, user-invented label (F-59) — "Terraza", "para grupos" — as
 * opposed to the closed [Cuisine] vocabulary. [name]'s `COLLATE NOCASE`
 * plus the unique index on it gives case-insensitive uniqueness at the
 * SQLite level: inserting "terraza" when "Terraza" already exists conflicts
 * against the same row instead of creating a near-duplicate.
 */
@Entity(tableName = "tags", indices = [Index(value = ["name"], unique = true)])
data class Tag(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    @ColumnInfo(collate = ColumnInfo.NOCASE)
    val name: String
)

/**
 * Join row linking a [Restaurant] to a [Tag]. Both foreign keys cascade on
 * delete: removing a restaurant or a tag cleans up the links pointing at it
 * without leaving orphaned rows in this table.
 */
@Entity(
    tableName = "restaurant_tags",
    primaryKeys = ["restaurantId", "tagId"],
    foreignKeys = [
        ForeignKey(
            entity = Restaurant::class,
            parentColumns = ["id"],
            childColumns = ["restaurantId"],
            onDelete = ForeignKey.CASCADE
        ),
        ForeignKey(
            entity = Tag::class,
            parentColumns = ["id"],
            childColumns = ["tagId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    // Without this, deleting a Tag (or any tagId-keyed lookup) forces a full
    // scan of this table: the composite primary key only covers lookups
    // that lead with restaurantId.
    indices = [Index(value = ["tagId"])]
)
data class RestaurantTag(
    val restaurantId: Long,
    val tagId: Long
)

/** Projection for [TagDao.observeAllRestaurantTagLinks] — one row per restaurant/tag-name pair. */
data class RestaurantTagName(
    val restaurantId: Long,
    val name: String
)
