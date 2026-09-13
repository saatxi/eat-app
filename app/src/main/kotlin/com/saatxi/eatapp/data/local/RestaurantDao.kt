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
     * CASE constant so the name order alone applies. "Rating" and "visited" now
     * resolve through the `visits` table rather than a restaurant-level column.
     *
     * [query] must already be folded with `normalizeForSearch` and escaped
     * with `escapeLikeWildcards`, since it is matched as a literal substring
     * of the equally folded `searchText` column — the `ESCAPE '\'` clause is
     * what makes `%` and `_` in the escaped query match themselves rather
     * than act as `LIKE` wildcards.
     */
    @Query(
        """
        SELECT * FROM restaurants r
        WHERE (:query IS NULL OR searchText LIKE '%' || :query || '%' ESCAPE '\')
          AND (:minRating IS NULL OR EXISTS (SELECT 1 FROM visits v WHERE v.restaurantId = r.id AND v.rating >= :minRating))
          AND (:cuisineType IS NULL OR cuisineType = :cuisineType)
          AND (
            :visited IS NULL
            OR (:visited = 1 AND EXISTS (SELECT 1 FROM visits v WHERE v.restaurantId = r.id))
            OR (:visited = 0 AND NOT EXISTS (SELECT 1 FROM visits v WHERE v.restaurantId = r.id))
          )
          AND (:city IS NULL OR city = :city)
          AND (:region IS NULL OR region = :region)
          AND (:country IS NULL OR country = :country)
          AND (:priceRange IS NULL OR priceRange = :priceRange)
        ORDER BY
          CASE WHEN :sortByRating THEN (SELECT MAX(v2.rating) FROM visits v2 WHERE v2.restaurantId = r.id) ELSE 0 END DESC,
          name COLLATE NOCASE ASC
        """
    )
    fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sortByRating: Boolean,
        visited: Boolean? = null,
        city: String? = null,
        region: String? = null,
        country: String? = null,
        priceRange: Int? = null
    ): Flow<List<Restaurant>>

    /**
     * The cuisine keys actually present in the data, so the filter row can offer
     * only those instead of all 24 entries of the vocabulary.
     */
    @Query("SELECT DISTINCT cuisineType FROM restaurants")
    fun observeCuisineTypes(): Flow<List<String>>

    /** Distinct, non-null [Restaurant.city] values actually present, for the location filter panel. */
    @Query("SELECT DISTINCT city FROM restaurants WHERE city IS NOT NULL ORDER BY city COLLATE NOCASE ASC")
    fun observeCities(): Flow<List<String>>

    /** Distinct, non-null [Restaurant.region] values actually present, for the location filter panel. */
    @Query("SELECT DISTINCT region FROM restaurants WHERE region IS NOT NULL ORDER BY region COLLATE NOCASE ASC")
    fun observeRegions(): Flow<List<String>>

    /** Distinct, non-null [Restaurant.country] values actually present, for the location filter panel. */
    @Query("SELECT DISTINCT country FROM restaurants WHERE country IS NOT NULL ORDER BY country COLLATE NOCASE ASC")
    fun observeCountries(): Flow<List<String>>

    @Query("SELECT * FROM restaurants WHERE id = :id")
    fun observeById(id: String): Flow<Restaurant?>

    /** A one-shot snapshot of every row, used to write the full `backup.json` after each write. */
    @Query("SELECT * FROM restaurants ORDER BY name COLLATE NOCASE ASC")
    suspend fun getAll(): List<Restaurant>

    @Insert
    suspend fun insert(restaurant: Restaurant)

    @Update
    suspend fun update(restaurant: Restaurant)

    @Query("DELETE FROM restaurants WHERE id = :id")
    suspend fun delete(id: String)

    @Query("DELETE FROM restaurants")
    suspend fun deleteAll()

    // --- Statistics (F-64) ---------------------------------------------
    //
    // Restaurant-level stats stay here; visit-derived ones (visited count,
    // average rating) moved to VisitDao since rating/visited no longer live
    // on this table.

    @Query("SELECT COUNT(*) FROM restaurants")
    fun observeTotalCount(): Flow<Int>

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
    @Query("SELECT * FROM restaurants WHERE NOT EXISTS (SELECT 1 FROM visits WHERE restaurantId = restaurants.id) ORDER BY RANDOM() LIMIT 1")
    suspend fun getRandomWantToTry(): Restaurant?
}
