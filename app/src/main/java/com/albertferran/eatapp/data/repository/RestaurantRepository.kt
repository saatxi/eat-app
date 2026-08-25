package com.albertferran.eatapp.data.repository

import com.albertferran.eatapp.data.local.Restaurant
import kotlinx.coroutines.flow.Flow

interface RestaurantRepository {
    fun observeAll(): Flow<List<Restaurant>>
    fun observeFiltered(query: String?, minRating: Int?): Flow<List<Restaurant>>
    fun observeById(id: Long): Flow<Restaurant?>
    suspend fun replaceAll(restaurants: List<Restaurant>)
}
