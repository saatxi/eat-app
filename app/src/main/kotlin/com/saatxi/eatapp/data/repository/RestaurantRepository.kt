package com.saatxi.eatapp.data.repository

import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import kotlinx.coroutines.flow.Flow

interface RestaurantRepository {
    fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort = RestaurantSort.NAME,
        visited: Boolean? = null
    ): Flow<List<Restaurant>>

    fun observeCuisineTypes(): Flow<List<String>>
    fun observeById(id: Long): Flow<Restaurant?>

    /** Returns the newly assigned id. [restaurant] must have `id == 0`. */
    suspend fun insert(restaurant: Restaurant): Long
    suspend fun update(restaurant: Restaurant)
    suspend fun delete(id: Long)
    suspend fun deleteAll()

    // --- Statistics (F-64) — see RestaurantDao for what each one queries ---
    fun observeTotalCount(): Flow<Int>
    fun observeVisitedCount(): Flow<Int>
    fun observeAverageRating(): Flow<Double?>
    fun observeCuisineCounts(): Flow<List<CuisineCount>>
    fun observePriceRangeCounts(): Flow<List<PriceRangeCount>>

    /** For the home-screen widget (F-68) — see `RestaurantDao.getRandomWantToTry`. */
    suspend fun getRandomWantToTry(): Restaurant?
}
