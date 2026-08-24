package com.albertferran.eatapp.data.repository

import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.local.RestaurantDao
import kotlinx.coroutines.flow.Flow

class RoomRestaurantRepository(
    private val dao: RestaurantDao
) : RestaurantRepository {

    override fun observeAll(): Flow<List<Restaurant>> = dao.observeFiltered(query = null, minRating = null)

    override fun observeFiltered(query: String?, minRating: Int?): Flow<List<Restaurant>> =
        dao.observeFiltered(query = query?.takeIf { it.isNotBlank() }, minRating = minRating)

    override fun observeById(id: Long): Flow<Restaurant?> = dao.observeById(id)

    override suspend fun upsert(restaurant: Restaurant): Long =
        if (restaurant.id == 0L) {
            dao.insert(restaurant)
        } else {
            dao.update(restaurant)
            restaurant.id
        }

    override suspend fun delete(restaurant: Restaurant) = dao.delete(restaurant)
}
