package com.saatxi.eatapp.data.repository

import android.content.Context
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantDao
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.local.escapeLikeWildcards
import com.saatxi.eatapp.data.local.normalizeForSearch
import com.saatxi.eatapp.data.photo.deleteAllRestaurantPhotoFiles
import com.saatxi.eatapp.data.photo.deleteRestaurantPhotoFile
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
        sort: RestaurantSort,
        visited: Boolean?
    ): Flow<List<Restaurant>> =
        dao.observeFiltered(
            query = query?.takeIf { it.isNotBlank() }?.let(::normalizeForSearch)?.let(::escapeLikeWildcards),
            minRating = minRating,
            cuisineType = cuisineType?.takeIf { it.isNotBlank() },
            // The DAO takes a flag rather than the enum, so the ordering stays a
            // bound parameter instead of SQL assembled from a value.
            sortByRating = sort == RestaurantSort.RATING,
            visited = visited
        )

    override fun observeCuisineTypes(): Flow<List<String>> = dao.observeCuisineTypes()

    override fun observeById(id: Long): Flow<Restaurant?> = dao.observeById(id)

    override suspend fun insert(restaurant: Restaurant): Long {
        val id = dao.insert(restaurant)
        writeBackup()
        return id
    }

    /**
     * The old photo — if this update moves the row away from it — is deleted only
     * *after* [dao.update] succeeds, so a mid-write failure can never leave a row
     * pointing at a file that's already gone.
     */
    override suspend fun update(restaurant: Restaurant) {
        val previousPhotoPath = dao.getPhotoPath(restaurant.id)
        dao.update(restaurant)
        if (previousPhotoPath != null && previousPhotoPath != restaurant.photoPath) {
            deleteRestaurantPhotoFile(previousPhotoPath)
        }
        writeBackup()
    }

    override suspend fun delete(id: Long) {
        val photoPath = dao.getPhotoPath(id)
        dao.delete(id)
        photoPath?.let(::deleteRestaurantPhotoFile)
        writeBackup()
    }

    override suspend fun deleteAll() {
        dao.deleteAll()
        // Every row is gone, so rather than looking up which of them had a photo,
        // the whole directory goes at once.
        deleteAllRestaurantPhotoFiles(context)
        writeBackup()
    }

    /** Keeps `backup.json` a full, current snapshot after every write — see [writeBackupFile]. */
    private suspend fun writeBackup() {
        writeBackupFile(context, dao.getAll().map { it.toExport() })
    }
}
