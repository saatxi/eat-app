package com.saatxi.eatapp.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface VisitDao {

    @Query("SELECT * FROM visits WHERE restaurantId = :restaurantId ORDER BY visitDate DESC")
    fun observeVisitsForRestaurant(restaurantId: String): Flow<List<Visit>>

    /** One-shot: the most recent visit, if any — used to prefill the edit form and derive the list-row rating. */
    @Query("SELECT * FROM visits WHERE restaurantId = :restaurantId ORDER BY visitDate DESC LIMIT 1")
    suspend fun getLatestVisit(restaurantId: String): Visit?

    /** Every restaurant's most recent visit in one shot — backs the list/favorites/roulette rows. */
    @Query(
        """
        SELECT v.* FROM visits v
        INNER JOIN (
            SELECT restaurantId, MAX(visitDate) AS maxDate FROM visits GROUP BY restaurantId
        ) latest ON latest.restaurantId = v.restaurantId AND latest.maxDate = v.visitDate
        """
    )
    fun observeLatestVisitByRestaurantId(): Flow<List<Visit>>

    @Insert
    suspend fun insert(visit: Visit)

    @Update
    suspend fun update(visit: Visit)

    @Query("DELETE FROM visits WHERE id = :id")
    suspend fun delete(id: String)

    @Query("DELETE FROM visits WHERE restaurantId = :restaurantId")
    suspend fun deleteAllForRestaurant(restaurantId: String)

    /** One-shot snapshot of every visit, used to write the full `backup.json` after each write. */
    @Query("SELECT * FROM visits")
    suspend fun getAll(): List<Visit>

    @Query("SELECT COUNT(DISTINCT restaurantId) FROM visits")
    fun observeVisitedCount(): Flow<Int>

    /** Null when nothing has a real visit yet. */
    @Query("SELECT AVG(rating) FROM visits")
    fun observeAverageRating(): Flow<Double?>
}
