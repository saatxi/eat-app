package com.saatxi.eatapp.data.repository

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import kotlinx.coroutines.flow.Flow

interface RestaurantRepository {
    fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort = RestaurantSort.NAME
    ): Flow<List<Restaurant>>

    fun observeCuisineTypes(): Flow<List<String>>
    fun observeById(id: Long): Flow<Restaurant?>
    suspend fun count(): Int
    suspend fun replaceAll(restaurants: List<Restaurant>)
}
