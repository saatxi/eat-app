package com.saatxi.eatapp.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

/**
 * An `abstract class`, not an `interface`, so [setTags]'s `@Transaction`
 * default method is a plain JVM method Room can call directly — this
 * project sets no `-Xjvm-default` compiler flag, and whether Room's codegen
 * honors `@Transaction` on a Kotlin *interface* default method depends on
 * that flag. This is Room's own documented way to sidestep the ambiguity.
 */
@Dao
abstract class TagDao {

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    abstract suspend fun insertTag(tag: Tag): Long

    @Query("SELECT id FROM tags WHERE name = :name")
    abstract suspend fun findTagId(name: String): Long?

    @Query("DELETE FROM restaurant_tags WHERE restaurantId = :restaurantId")
    abstract suspend fun deleteLinks(restaurantId: Long)

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    abstract suspend fun insertLinks(links: List<RestaurantTag>)

    @Query("DELETE FROM tags")
    abstract suspend fun deleteAllTags()

    @Query("SELECT name FROM tags ORDER BY name COLLATE NOCASE")
    abstract fun observeAllTagNames(): Flow<List<String>>

    @Query(
        """
        SELECT t.name FROM tags t
        JOIN restaurant_tags rt ON t.id = rt.tagId
        WHERE rt.restaurantId = :restaurantId
        ORDER BY t.name COLLATE NOCASE
        """
    )
    abstract fun observeTagNames(restaurantId: Long): Flow<List<String>>

    /** Backs `RestaurantRepository.observeTagsByRestaurantId()` — one query, grouped by the caller. */
    @Query(
        """
        SELECT rt.restaurantId AS restaurantId, t.name AS name
        FROM restaurant_tags rt
        JOIN tags t ON t.id = rt.tagId
        """
    )
    abstract fun observeAllRestaurantTagLinks(): Flow<List<RestaurantTagName>>

    /**
     * Replaces every tag link for [restaurantId] with [tagNames], creating
     * any tag that doesn't already exist (case-insensitively — see [Tag.name]).
     * [tagNames] is de-duplicated up front and both inserts ignore conflicts,
     * so a caller that (by mistake) passes case-insensitive duplicates gets a
     * no-op instead of a `SQLiteConstraintException` aborting the save.
     */
    @Transaction
    open suspend fun setTags(restaurantId: Long, tagNames: List<String>) {
        val distinctNames = tagNames.distinctBy { it.trim().lowercase() }
        deleteLinks(restaurantId)
        val tagIds = distinctNames.map { name ->
            findTagId(name) ?: insertTag(Tag(name = name)).let { insertedId ->
                // -1 means insertTag's own IGNORE fired (a concurrent insert
                // won the race between findTagId and insertTag) — look the
                // row up again instead of writing a link to a nonexistent tag.
                if (insertedId == -1L) findTagId(name)!! else insertedId
            }
        }
        insertLinks(tagIds.map { tagId -> RestaurantTag(restaurantId = restaurantId, tagId = tagId) })
    }
}
