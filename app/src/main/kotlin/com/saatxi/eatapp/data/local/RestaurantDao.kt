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
          AND (:visited IS NULL OR visited = :visited)
        ORDER BY
          CASE WHEN :sortByRating THEN rating ELSE 0 END DESC,
          name COLLATE NOCASE ASC
        """
    )
    fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sortByRating: Boolean,
        visited: Boolean? = null
    ): Flow<List<Restaurant>>

    /**
     * The cuisine keys actually present in the data, so the filter row can offer
     * only those instead of all 24 entries of the vocabulary.
     */
    @Query("SELECT DISTINCT cuisineType FROM restaurants")
    fun observeCuisineTypes(): Flow<List<String>>

    @Query("SELECT * FROM restaurants WHERE id = :id")
    fun observeById(id: Long): Flow<Restaurant?>

    /**
     * A one-shot read of just the photo path, used by the repository to know
     * what file (if any) to delete once [update] or [delete] has moved a row
     * past its old photo — see `RoomRestaurantRepository`.
     */
    @Query("SELECT photoPath FROM restaurants WHERE id = :id")
    suspend fun getPhotoPath(id: Long): String?

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

    // --- Statistics (F-64) ---------------------------------------------
    //
    // Five small, independent queries rather than one hand-assembled
    // aggregate object: each maps directly to one GROUP BY/aggregate and
    // stays trivial to read, and StatisticsViewModel's own combine() (a
    // typed 5-flow overload, not the untyped vararg one — see F-3's history
    // of that exact overload boundary) is what turns them into one state.

    @Query("SELECT COUNT(*) FROM restaurants")
    fun observeTotalCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM restaurants WHERE visited = 1")
    fun observeVisitedCount(): Flow<Int>

    /** Null when nothing has a real rating yet — a want-to-try row's `rating = 0` doesn't count as one. */
    @Query("SELECT AVG(rating) FROM restaurants WHERE rating > 0")
    fun observeAverageRating(): Flow<Double?>

    @Query("SELECT cuisineType, COUNT(*) AS count FROM restaurants GROUP BY cuisineType ORDER BY count DESC")
    fun observeCuisineCounts(): Flow<List<CuisineCount>>

    @Query("SELECT priceRange, COUNT(*) AS count FROM restaurants GROUP BY priceRange")
    fun observePriceRangeCounts(): Flow<List<PriceRangeCount>>

    /**
     * One random want-to-try restaurant, for the home-screen widget (F-68) —
     * a one-shot suspend query rather than a `Flow`, since the widget queries
     * this itself each time it (re)renders instead of observing a live stream.
     * Null when nothing is marked want-to-try.
     */
    @Query("SELECT * FROM restaurants WHERE visited = 0 ORDER BY RANDOM() LIMIT 1")
    suspend fun getRandomWantToTry(): Restaurant?
}
