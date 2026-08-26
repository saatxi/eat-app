package com.albertferran.eatapp.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

@Dao
interface RestaurantDao {

    @Query(
        """
        SELECT * FROM restaurants
        WHERE (:query IS NULL OR
               name LIKE '%' || :query || '%' OR
               cuisineType LIKE '%' || :query || '%' OR
               address LIKE '%' || :query || '%' OR
               notes LIKE '%' || :query || '%')
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
