package com.saatxi.eatapp.data.repository

import android.content.Context
import androidx.room.withTransaction
import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.EatAppDatabase
import com.saatxi.eatapp.data.local.Photo
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.local.TagCount
import com.saatxi.eatapp.data.local.Visit
import com.saatxi.eatapp.data.local.VisitDateRating
import com.saatxi.eatapp.data.local.escapeLikeWildcards
import com.saatxi.eatapp.data.local.normalizeForSearch
import com.saatxi.eatapp.data.photo.deleteAllRestaurantPhotoFiles
import com.saatxi.eatapp.data.photo.deleteRestaurantPhotoFile
import com.saatxi.eatapp.data.share.toExport
import com.saatxi.eatapp.data.share.writeBackupFile
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

@Singleton
class RoomRestaurantRepository @Inject constructor(
    private val database: EatAppDatabase,
    @ApplicationContext private val context: Context
) : RestaurantRepository {

    private val dao = database.restaurantDao()
    private val tagDao = database.tagDao()
    private val visitDao = database.visitDao()
    private val photoDao = database.photoDao()

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort,
        visited: Boolean?,
        city: String?,
        region: String?,
        country: String?
    ): Flow<List<Restaurant>> =
        dao.observeFiltered(
            query = query?.takeIf { it.isNotBlank() }?.let(::normalizeForSearch)?.let(::escapeLikeWildcards),
            minRating = minRating,
            cuisineType = cuisineType?.takeIf { it.isNotBlank() },
            // The DAO takes a flag rather than the enum, so the ordering stays a
            // bound parameter instead of SQL assembled from a value.
            sortByRating = sort == RestaurantSort.RATING,
            visited = visited,
            city = city?.takeIf { it.isNotBlank() },
            region = region?.takeIf { it.isNotBlank() },
            country = country?.takeIf { it.isNotBlank() }
        )

    override fun observeCuisineTypes(): Flow<List<String>> = dao.observeCuisineTypes()
    override fun observeCities(): Flow<List<String>> = dao.observeCities()
    override fun observeRegions(): Flow<List<String>> = dao.observeRegions()
    override fun observeCountries(): Flow<List<String>> = dao.observeCountries()

    override fun observeById(id: String): Flow<Restaurant?> = dao.observeById(id)

    override suspend fun insert(restaurant: Restaurant, tags: List<String>) {
        database.withTransaction {
            dao.insert(restaurant)
            tagDao.setTags(restaurant.id, tags)
        }
        writeBackup()
    }

    override suspend fun update(restaurant: Restaurant, tags: List<String>) {
        database.withTransaction {
            dao.update(restaurant)
            tagDao.setTags(restaurant.id, tags)
        }
        writeBackup()
    }

    override suspend fun delete(id: String) {
        val photoPath = photoDao.getFirstPhotoForRestaurant(id)?.path
        // No explicit tag/visit/photo cleanup needed: they all cascade on delete.
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
        val visitsByRestaurantId = visitDao.getAll().groupBy { it.restaurantId }
        writeBackupFile(
            context,
            dao.getAll().map {
                it.toExport(tagsByRestaurantId[it.id].orEmpty(), visitsByRestaurantId[it.id].orEmpty())
            }
        )
    }

    override fun observeAllTagNames(): Flow<List<String>> = tagDao.observeAllTagNames()
    override fun observeTagNames(restaurantId: String): Flow<List<String>> = tagDao.observeTagNames(restaurantId)
    override fun observeTagsByRestaurantId(): Flow<Map<String, List<String>>> =
        tagDao.observeAllRestaurantTagLinks().map { links -> links.groupBy({ it.restaurantId }, { it.name }) }

    override fun observeTotalCount(): Flow<Int> = dao.observeTotalCount()
    override fun observeVisitedCount(): Flow<Int> = visitDao.observeVisitedCount()
    override fun observeAverageRating(): Flow<Double?> = visitDao.observeAverageRating()
    override fun observeCuisineCounts(): Flow<List<CuisineCount>> = dao.observeCuisineCounts()
    override fun observePriceRangeCounts(): Flow<List<PriceRangeCount>> = dao.observePriceRangeCounts()
    override fun observeTagCounts(): Flow<List<TagCount>> = tagDao.observeTagCounts()
    override fun observeAllVisitDates(): Flow<List<Long>> = visitDao.observeAllVisitDates()
    override fun observeAllVisitDateRatings(): Flow<List<VisitDateRating>> = visitDao.observeAllVisitDateRatings()

    override suspend fun getRandomWantToTry(): Restaurant? = dao.getRandomWantToTry()

    override fun observeVisitsForRestaurant(restaurantId: String): Flow<List<Visit>> =
        visitDao.observeVisitsForRestaurant(restaurantId)

    override fun observeLatestVisitByRestaurantId(): Flow<Map<String, Visit>> =
        visitDao.observeLatestVisitByRestaurantId().map { visits -> visits.associateBy { it.restaurantId } }

    override suspend fun getLatestVisit(restaurantId: String): Visit? = visitDao.getLatestVisit(restaurantId)

    override suspend fun saveSingleVisit(restaurantId: String, visited: Boolean, rating: Int, notes: String?) {
        database.withTransaction {
            val existing = visitDao.getLatestVisit(restaurantId)
            visitDao.deleteAllForRestaurant(restaurantId)
            if (visited) {
                visitDao.insert(
                    Visit(
                        id = existing?.id ?: UUID.randomUUID().toString(),
                        restaurantId = restaurantId,
                        visitDate = existing?.visitDate ?: System.currentTimeMillis(),
                        rating = rating,
                        notes = notes
                    )
                )
            }
        }
        writeBackup()
    }

    override suspend fun addVisit(restaurantId: String, visitDate: Long, rating: Int, notes: String?, priceRange: Int) {
        visitDao.insert(
            Visit(id = UUID.randomUUID().toString(), restaurantId = restaurantId, visitDate = visitDate, rating = rating, notes = notes, priceRange = priceRange)
        )
        writeBackup()
    }

    override suspend fun addVisit(
        restaurantId: String,
        visitDate: Long,
        rating: Int,
        notes: String?,
        priceRange: Int,
        photoPaths: List<String>
    ): String {
        val visitId = UUID.randomUUID().toString()
        database.withTransaction {
            visitDao.insert(
                Visit(id = visitId, restaurantId = restaurantId, visitDate = visitDate, rating = rating, notes = notes, priceRange = priceRange)
            )
            photoPaths.forEachIndexed { index, path ->
                photoDao.insert(Photo(id = UUID.randomUUID().toString(), visitId = visitId, path = path, position = index))
            }
        }
        writeBackup()
        return visitId
    }

    override suspend fun deleteVisit(id: String) {
        visitDao.delete(id)
        writeBackup()
    }

    override fun observePhotosForRestaurant(restaurantId: String): Flow<List<Photo>> =
        photoDao.observePhotosForRestaurant(restaurantId)

    override fun observePhotosForVisit(visitId: String): Flow<List<Photo>> =
        photoDao.observePhotosForVisit(visitId)

    override suspend fun getRestaurantPhotoPath(restaurantId: String): String? =
        photoDao.getFirstPhotoForRestaurant(restaurantId)?.path

    override suspend fun addRestaurantPhotos(restaurantId: String, photoPaths: List<String>) {
        if (photoPaths.isEmpty()) return
        val startPosition = photoDao.getMaxPositionForRestaurant(restaurantId) + 1
        database.withTransaction {
            photoPaths.forEachIndexed { index, path ->
                photoDao.insert(
                    Photo(id = UUID.randomUUID().toString(), restaurantId = restaurantId, path = path, position = startPosition + index)
                )
            }
        }
        writeBackup()
    }

    /** The row is deleted first, then its file — a mid-write failure never leaves a row pointing at a missing file. */
    override suspend fun deletePhoto(id: String) {
        val photo = photoDao.getById(id)
        photoDao.delete(id)
        photo?.path?.let(::deleteRestaurantPhotoFile)
        writeBackup()
    }
}
