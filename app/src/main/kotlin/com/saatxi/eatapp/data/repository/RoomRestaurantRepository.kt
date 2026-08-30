package com.saatxi.eatapp.data.repository

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantDao
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.local.escapeLikeWildcards
import com.saatxi.eatapp.data.local.normalizeForSearch
import kotlinx.coroutines.flow.Flow

class RoomRestaurantRepository(
    private val dao: RestaurantDao
) : RestaurantRepository {

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort
    ): Flow<List<Restaurant>> =
        dao.observeFiltered(
            query = query?.takeIf { it.isNotBlank() }?.let(::normalizeForSearch)?.let(::escapeLikeWildcards),
            minRating = minRating,
            cuisineType = cuisineType?.takeIf { it.isNotBlank() },
            // The DAO takes a flag rather than the enum, so the ordering stays a
            // bound parameter instead of SQL assembled from a value.
            sortByRating = sort == RestaurantSort.RATING
        )

    override fun observeCuisineTypes(): Flow<List<String>> = dao.observeCuisineTypes()

    override fun observeById(id: Long): Flow<Restaurant?> = dao.observeById(id)

    override suspend fun insert(restaurant: Restaurant): Long = dao.insert(restaurant)

    override suspend fun update(restaurant: Restaurant) = dao.update(restaurant)

    override suspend fun delete(id: Long) = dao.delete(id)
}
