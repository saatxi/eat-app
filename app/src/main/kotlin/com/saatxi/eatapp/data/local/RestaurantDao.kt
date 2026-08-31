package com.saatxi.eatapp.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface RestaurantDao {

    /**
     * Ordering is fixed by [sortByRating] rather than interpolated into the SQL:
     * true puts the highest ratings first (name breaking ties), false leaves the
     * CASE constant so the name order alone applies.
     *
     * [query] must already be folded with `normalizeForSearch` and escaped
     * with `escapeLikeWildcards`, since it is matched as a literal substring
     * of the equally folded `searchText` column — the `ESCAPE '\'` clause is
     * what makes `%` and `_` in the escaped query match themselves rather
     * than act as `LIKE` wildcards.
     */
    @Query(
        """
        SELECT * FROM restaurants
        WHERE (:query IS NULL OR searchText LIKE '%' || :query || '%' ESCAPE '\')
          AND (:minRating IS NULL OR rating >= :minRating)
          AND (:cuisineType IS NULL OR cuisineType = :cuisineType)
        ORDER BY
          CASE WHEN :sortByRating THEN rating ELSE 0 END DESC,
          name COLLATE NOCASE ASC
        """
    )
    fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sortByRating: Boolean
    ): Flow<List<Restaurant>>

    /**
     * The cuisine keys actually present in the data, so the filter row can offer
     * only those instead of all 24 entries of the vocabulary.
     */
    @Query("SELECT DISTINCT cuisineType FROM restaurants")
    fun observeCuisineTypes(): Flow<List<String>>

    @Query("SELECT * FROM restaurants WHERE id = :id")
    fun observeById(id: Long): Flow<Restaurant?>

    /** A one-shot snapshot of every row, used to write the full `backup.json` after each write. */
    @Query("SELECT * FROM restaurants ORDER BY name COLLATE NOCASE ASC")
    suspend fun getAll(): List<Restaurant>

    /** [Restaurant.id] must be 0 (the default) so Room assigns a fresh one. */
    @Insert
    suspend fun insert(restaurant: Restaurant): Long

    @Update
    suspend fun update(restaurant: Restaurant)

    @Query("DELETE FROM restaurants WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("DELETE FROM restaurants")
    suspend fun deleteAll()
}
