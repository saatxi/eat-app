package com.saatxi.eatapp.data.repository

import android.content.Context
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantDao
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.local.escapeLikeWildcards
import com.saatxi.eatapp.data.local.normalizeForSearch
import com.saatxi.eatapp.data.share.toExport
import com.saatxi.eatapp.data.share.writeBackupFile
import kotlinx.coroutines.flow.Flow

class RoomRestaurantRepository(
    private val dao: RestaurantDao,
    private val context: Context
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

    override suspend fun insert(restaurant: Restaurant): Long {
        val id = dao.insert(restaurant)
        writeBackup()
        return id
    }

    override suspend fun update(restaurant: Restaurant) {
        dao.update(restaurant)
        writeBackup()
    }

    override suspend fun delete(id: Long) {
        dao.delete(id)
        writeBackup()
    }

    override suspend fun deleteAll() {
        dao.deleteAll()
        writeBackup()
    }

    /** Keeps `backup.json` a full, current snapshot after every write — see [writeBackupFile]. */
    private suspend fun writeBackup() {
        writeBackupFile(context, dao.getAll().map { it.toExport() })
    }
}
