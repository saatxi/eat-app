package com.albertferran.eatapp.data.repository

import com.albertferran.eatapp.data.local.Restaurant
import kotlinx.coroutines.flow.Flow

interface RestaurantRepository {
    fun observeFiltered(query: String?, minRating: Int?, cuisineType: String?): Flow<List<Restaurant>>
    fun observeCuisineTypes(): Flow<List<String>>
    fun observeById(id: Long): Flow<Restaurant?>
    suspend fun count(): Int
    suspend fun replaceAll(restaurants: List<Restaurant>)
}
