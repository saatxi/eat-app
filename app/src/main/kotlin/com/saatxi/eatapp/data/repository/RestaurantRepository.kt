package com.saatxi.eatapp.data.repository

import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.Photo
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.local.TagCount
import com.saatxi.eatapp.data.local.Visit
import kotlinx.coroutines.flow.Flow

interface RestaurantRepository {
    fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort = RestaurantSort.NAME,
        visited: Boolean? = null,
        city: String? = null,
        region: String? = null,
        country: String? = null
    ): Flow<List<Restaurant>>

    fun observeCuisineTypes(): Flow<List<String>>
    fun observeCities(): Flow<List<String>>
    fun observeRegions(): Flow<List<String>>
    fun observeCountries(): Flow<List<String>>
    fun observeById(id: String): Flow<Restaurant?>

    /** [restaurant.id] must already be a freshly generated UUID. [tags] replaces any prior tags in the same write. */
    suspend fun insert(restaurant: Restaurant, tags: List<String> = emptyList())
    suspend fun update(restaurant: Restaurant, tags: List<String>)
    suspend fun delete(id: String)
    suspend fun deleteAll()

    // --- Tags (F-59) -----------------------------------------------------
    fun observeAllTagNames(): Flow<List<String>>
    fun observeTagNames(restaurantId: String): Flow<List<String>>
    fun observeTagsByRestaurantId(): Flow<Map<String, List<String>>>

    // --- Statistics (F-64) — see RestaurantDao/VisitDao for what each one queries ---
    fun observeTotalCount(): Flow<Int>
    fun observeVisitedCount(): Flow<Int>
    fun observeAverageRating(): Flow<Double?>
    fun observeCuisineCounts(): Flow<List<CuisineCount>>
    fun observePriceRangeCounts(): Flow<List<PriceRangeCount>>
    fun observeTagCounts(): Flow<List<TagCount>>
    /** Every visit's raw date, across every restaurant — bucketed into months by `StatisticsViewModel`. */
    fun observeAllVisitDates(): Flow<List<Long>>

    /** For the home-screen widget (F-68) — see `RestaurantDao.getRandomWantToTry`. */
    suspend fun getRandomWantToTry(): Restaurant?

    // --- Visits ------------------------------------------------------------
    fun observeVisitsForRestaurant(restaurantId: String): Flow<List<Visit>>
    /** Every restaurant's most recent visit, keyed by restaurantId — backs the list/favorites/roulette rows. */
    fun observeLatestVisitByRestaurantId(): Flow<Map<String, Visit>>
    suspend fun getLatestVisit(restaurantId: String): Visit?

    /**
     * Replaces every visit a restaurant has with zero-or-one, matching today's
     * single-rating edit form: [visited] false clears all visits, true writes
     * one with [rating]/[notes], reusing the existing visit's date when there
     * was one so re-saving the form doesn't reset it to "now" every time.
     */
    suspend fun saveSingleVisit(restaurantId: String, visited: Boolean, rating: Int, notes: String?)
    /** Adds one more visit — used by import, which may carry a full visit history rather than just one. */
    suspend fun addVisit(restaurantId: String, visitDate: Long, rating: Int, notes: String?)

    /**
     * Adds one new visit together with any photos taken on it — the real,
     * multi-visit-per-restaurant path used by the log-visit screen (unlike
     * [addVisit] above, kept only for import's simpler restaurant-at-a-time
     * replay). Returns the new visit's id.
     */
    suspend fun addVisit(restaurantId: String, visitDate: Long, rating: Int, notes: String?, photoPaths: List<String>): String
    suspend fun deleteVisit(id: String)

    // --- Photos --------------------------------------------------------
    fun observePhotosForRestaurant(restaurantId: String): Flow<List<Photo>>
    fun observePhotosForVisit(visitId: String): Flow<List<Photo>>
    suspend fun getRestaurantPhotoPath(restaurantId: String): String?
    /** Appends [photoPaths] as new restaurant-level photos, after whatever's already there. No-op for an empty list. */
    suspend fun addRestaurantPhotos(restaurantId: String, photoPaths: List<String>)
    /** Deletes one photo row (restaurant- or visit-level) and the file it points at. */
    suspend fun deletePhoto(id: String)
}
