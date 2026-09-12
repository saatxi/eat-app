package com.saatxi.eatapp.data.repository

import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.Photo
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.local.TagCount
import com.saatxi.eatapp.data.local.Visit
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map

/**
 * A single shared, hand-written fake `RestaurantRepository` for ViewModel
 * tests — this project has no mocking library (see CLAUDE.md). Every method
 * either replays a `MutableStateFlow` the test pushes into, or records what
 * the ViewModel passed down for the test to assert on afterward. Nothing here
 * filters or joins anything itself — that behaviour belongs to the DAO and is
 * covered by `RestaurantDaoTest`.
 */
class FakeRestaurantRepository : RestaurantRepository {

    val restaurants = MutableStateFlow<List<Restaurant>>(emptyList())
    val cuisines = MutableStateFlow<List<String>>(emptyList())
    val cities = MutableStateFlow<List<String>>(emptyList())
    val regions = MutableStateFlow<List<String>>(emptyList())
    val countries = MutableStateFlow<List<String>>(emptyList())
    val tagsByRestaurantId = MutableStateFlow<Map<String, List<String>>>(emptyMap())
    val latestVisitByRestaurantId = MutableStateFlow<Map<String, Visit>>(emptyMap())
    val totalCount = MutableStateFlow(0)
    val visitedCount = MutableStateFlow(0)
    val averageRating = MutableStateFlow<Double?>(null)
    val cuisineCounts = MutableStateFlow<List<CuisineCount>>(emptyList())
    val priceRangeCounts = MutableStateFlow<List<PriceRangeCount>>(emptyList())
    val tagCounts = MutableStateFlow<List<TagCount>>(emptyList())
    val allVisitDates = MutableStateFlow<List<Long>>(emptyList())
    var randomWantToTry: Restaurant? = null

    var lastQuery: String? = null
        private set
    var lastMinRating: Int? = null
        private set
    var lastCuisine: String? = null
        private set
    var lastSort: RestaurantSort? = null
        private set
    var lastVisited: Boolean? = null
        private set
    var lastCity: String? = null
        private set
    var lastRegion: String? = null
        private set
    var lastCountry: String? = null
        private set
    var lastDeletedId: String? = null
        private set
    var lastInserted: Restaurant? = null
        private set
    var lastInsertedTags: List<String>? = null
        private set
    var lastUpdated: Restaurant? = null
        private set
    var lastUpdatedTags: List<String>? = null
        private set
    var lastSingleVisit: Triple<String, Boolean, Int>? = null
        private set
    var lastPhotoPath: String? = null
        private set

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort,
        visited: Boolean?,
        city: String?,
        region: String?,
        country: String?
    ): Flow<List<Restaurant>> {
        lastQuery = query
        lastMinRating = minRating
        lastCuisine = cuisineType
        lastSort = sort
        lastVisited = visited
        lastCity = city
        lastRegion = region
        lastCountry = country
        return restaurants
    }

    override fun observeCuisineTypes(): Flow<List<String>> = cuisines
    override fun observeCities(): Flow<List<String>> = cities
    override fun observeRegions(): Flow<List<String>> = regions
    override fun observeCountries(): Flow<List<String>> = countries

    override fun observeById(id: String): Flow<Restaurant?> =
        restaurants.map { list -> list.firstOrNull { it.id == id } }

    override suspend fun insert(restaurant: Restaurant, tags: List<String>) {
        lastInserted = restaurant
        lastInsertedTags = tags
        restaurants.value = restaurants.value + restaurant
    }

    override suspend fun update(restaurant: Restaurant, tags: List<String>) {
        lastUpdated = restaurant
        lastUpdatedTags = tags
        restaurants.value = restaurants.value.map { if (it.id == restaurant.id) restaurant else it }
    }

    override suspend fun delete(id: String) {
        lastDeletedId = id
        restaurants.value = restaurants.value.filterNot { it.id == id }
    }

    override suspend fun deleteAll() {
        restaurants.value = emptyList()
    }

    override fun observeAllTagNames(): Flow<List<String>> = tagsByRestaurantId.map { it.values.flatten().distinct() }

    override fun observeTagNames(restaurantId: String): Flow<List<String>> =
        tagsByRestaurantId.map { it[restaurantId].orEmpty() }

    override fun observeTagsByRestaurantId(): Flow<Map<String, List<String>>> = tagsByRestaurantId

    override fun observeTotalCount(): Flow<Int> = totalCount
    override fun observeVisitedCount(): Flow<Int> = visitedCount
    override fun observeAverageRating(): Flow<Double?> = averageRating
    override fun observeCuisineCounts(): Flow<List<CuisineCount>> = cuisineCounts
    override fun observePriceRangeCounts(): Flow<List<PriceRangeCount>> = priceRangeCounts
    override fun observeTagCounts(): Flow<List<TagCount>> = tagCounts
    override fun observeAllVisitDates(): Flow<List<Long>> = allVisitDates

    override suspend fun getRandomWantToTry(): Restaurant? = randomWantToTry

    /**
     * Full multi-visit history per restaurant, for tests that need a real
     * timeline rather than just the single latest-visit summary
     * [latestVisitByRestaurantId] tracks. Empty by default; when unset for a
     * given id, [observeVisitsForRestaurant] falls back to that latest-visit
     * map so existing single-visit tests don't need to change.
     */
    val visitsByRestaurantId = MutableStateFlow<Map<String, List<Visit>>>(emptyMap())

    override fun observeVisitsForRestaurant(restaurantId: String): Flow<List<Visit>> =
        combine(visitsByRestaurantId, latestVisitByRestaurantId) { visitsMap, latestMap ->
            visitsMap[restaurantId] ?: listOfNotNull(latestMap[restaurantId])
        }

    override fun observeLatestVisitByRestaurantId(): Flow<Map<String, Visit>> = latestVisitByRestaurantId

    override suspend fun getLatestVisit(restaurantId: String): Visit? = latestVisitByRestaurantId.value[restaurantId]

    override suspend fun saveSingleVisit(restaurantId: String, visited: Boolean, rating: Int, notes: String?) {
        lastSingleVisit = Triple(restaurantId, visited, rating)
        latestVisitByRestaurantId.value = if (visited) {
            latestVisitByRestaurantId.value + (restaurantId to Visit(id = "fake-visit", restaurantId = restaurantId, visitDate = 0L, rating = rating, notes = notes))
        } else {
            latestVisitByRestaurantId.value - restaurantId
        }
    }

    override suspend fun addVisit(restaurantId: String, visitDate: Long, rating: Int, notes: String?) {
        latestVisitByRestaurantId.value = latestVisitByRestaurantId.value +
            (restaurantId to Visit(id = "fake-visit-$visitDate", restaurantId = restaurantId, visitDate = visitDate, rating = rating, notes = notes))
    }

    var lastAddedVisit: Visit? = null
        private set
    var lastAddedVisitPhotoPaths: List<String>? = null
        private set

    override suspend fun addVisit(
        restaurantId: String,
        visitDate: Long,
        rating: Int,
        notes: String?,
        photoPaths: List<String>
    ): String {
        val visit = Visit(id = "fake-visit-new-$visitDate", restaurantId = restaurantId, visitDate = visitDate, rating = rating, notes = notes)
        lastAddedVisit = visit
        lastAddedVisitPhotoPaths = photoPaths
        latestVisitByRestaurantId.value = latestVisitByRestaurantId.value + (restaurantId to visit)
        return visit.id
    }

    override suspend fun deleteVisit(id: String) {
        latestVisitByRestaurantId.value = latestVisitByRestaurantId.value.filterValues { it.id != id }
    }

    /** Empty by default; a test that cares about a restaurant's photos can push into this. */
    val photosByRestaurantId = MutableStateFlow<Map<String, List<Photo>>>(emptyMap())

    override fun observePhotosForRestaurant(restaurantId: String): Flow<List<Photo>> =
        photosByRestaurantId.map { it[restaurantId].orEmpty() }

    /** Empty by default; a test that cares about a visit's photos can push into [photosByVisitId]. */
    val photosByVisitId = MutableStateFlow<Map<String, List<Photo>>>(emptyMap())

    override fun observePhotosForVisit(visitId: String): Flow<List<Photo>> =
        photosByVisitId.map { it[visitId].orEmpty() }

    override suspend fun getRestaurantPhotoPath(restaurantId: String): String? = lastPhotoPath

    var lastAddedRestaurantPhotos: Pair<String, List<String>>? = null
        private set

    override suspend fun addRestaurantPhotos(restaurantId: String, photoPaths: List<String>) {
        lastAddedRestaurantPhotos = restaurantId to photoPaths
        lastPhotoPath = photoPaths.lastOrNull() ?: lastPhotoPath
    }

    var lastDeletedPhotoId: String? = null
        private set

    override suspend fun deletePhoto(id: String) {
        lastDeletedPhotoId = id
    }
}
