package com.saatxi.eatapp.data.repository

import android.content.Context
import androidx.room.withTransaction
import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.EatAppDatabase
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.local.escapeLikeWildcards
import com.saatxi.eatapp.data.local.normalizeForSearch
import com.saatxi.eatapp.data.photo.deleteAllRestaurantPhotoFiles
import com.saatxi.eatapp.data.photo.deleteRestaurantPhotoFile
import com.saatxi.eatapp.data.share.toExport
import com.saatxi.eatapp.data.share.writeBackupFile
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

class RoomRestaurantRepository(
    private val database: EatAppDatabase,
    private val context: Context
) : RestaurantRepository {

    private val dao = database.restaurantDao()
    private val tagDao = database.tagDao()

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

    override suspend fun insert(restaurant: Restaurant, tags: List<String>): Long {
        val id = database.withTransaction {
            val newId = dao.insert(restaurant)
            tagDao.setTags(newId, tags)
            newId
        }
        writeBackup()
        return id
    }

    /**
     * The old photo — if this update moves the row away from it — is deleted only
     * *after* the transaction below succeeds, so a mid-write failure can never
     * leave a row pointing at a file that's already gone.
     */
    override suspend fun update(restaurant: Restaurant, tags: List<String>) {
        val previousPhotoPath = dao.getPhotoPath(restaurant.id)
        database.withTransaction {
            dao.update(restaurant)
            tagDao.setTags(restaurant.id, tags)
        }
        if (previousPhotoPath != null && previousPhotoPath != restaurant.photoPath) {
            deleteRestaurantPhotoFile(previousPhotoPath)
        }
        writeBackup()
    }

    override suspend fun delete(id: Long) {
        val photoPath = dao.getPhotoPath(id)
        // No explicit tag cleanup needed: restaurant_tags cascades on delete.
        dao.delete(id)
        photoPath?.let(::deleteRestaurantPhotoFile)
        writeBackup()
    }

    override suspend fun deleteAll() {
        database.withTransaction {
            dao.deleteAll()
            // Cascade only clears restaurant_tags when restaurants are
            // deleted — the tags table itself needs its own wipe.
            tagDao.deleteAllTags()
        }
        // Every row is gone, so rather than looking up which of them had a photo,
        // the whole directory goes at once.
        deleteAllRestaurantPhotoFiles(context)
        writeBackup()
    }

    /** Keeps `backup.json` a full, current snapshot after every write — see [writeBackupFile]. */
    private suspend fun writeBackup() {
        val tagsByRestaurantId = tagDao.observeAllRestaurantTagLinks().first()
            .groupBy({ it.restaurantId }, { it.name })
        writeBackupFile(context, dao.getAll().map { it.toExport(tagsByRestaurantId[it.id].orEmpty()) })
    }

    override fun observeAllTagNames(): Flow<List<String>> = tagDao.observeAllTagNames()
    override fun observeTagNames(restaurantId: Long): Flow<List<String>> = tagDao.observeTagNames(restaurantId)
    override fun observeTagsByRestaurantId(): Flow<Map<Long, List<String>>> =
        tagDao.observeAllRestaurantTagLinks().map { links -> links.groupBy({ it.restaurantId }, { it.name }) }

    override fun observeTotalCount(): Flow<Int> = dao.observeTotalCount()
    override fun observeVisitedCount(): Flow<Int> = dao.observeVisitedCount()
    override fun observeAverageRating(): Flow<Double?> = dao.observeAverageRating()
    override fun observeCuisineCounts(): Flow<List<CuisineCount>> = dao.observeCuisineCounts()
    override fun observePriceRangeCounts(): Flow<List<PriceRangeCount>> = dao.observePriceRangeCounts()

    override suspend fun getRandomWantToTry(): Restaurant? = dao.getRandomWantToTry()
}
