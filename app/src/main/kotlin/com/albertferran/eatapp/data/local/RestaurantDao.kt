package com.albertferran.eatapp.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

@Dao
interface RestaurantDao {

    /**
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
        ORDER BY name COLLATE NOCASE ASC
        """
    )
    fun observeFiltered(query: String?, minRating: Int?, cuisineType: String?): Flow<List<Restaurant>>

    /**
     * The cuisine keys actually present in the data, so the filter row can offer
     * only those instead of all 22 entries of the vocabulary.
     */
    @Query("SELECT DISTINCT cuisineType FROM restaurants")
    fun observeCuisineTypes(): Flow<List<String>>

    @Query("SELECT * FROM restaurants WHERE id = :id")
    fun observeById(id: Long): Flow<Restaurant?>

    @Query("SELECT COUNT(*) FROM restaurants")
    suspend fun count(): Int

    @Query("DELETE FROM restaurants")
    suspend fun deleteAll()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(restaurants: List<Restaurant>)

    @Transaction
    suspend fun replaceAll(restaurants: List<Restaurant>) {
        deleteAll()
        insertAll(restaurants)
    }
}
