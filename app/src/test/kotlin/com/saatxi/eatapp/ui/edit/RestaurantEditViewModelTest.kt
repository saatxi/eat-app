package com.saatxi.eatapp.ui.edit

import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.Photo
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.local.Visit
import com.saatxi.eatapp.data.photo.RestaurantPhotoStorage
import com.saatxi.eatapp.data.repository.RestaurantRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class RestaurantEditViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var repository: FakeRestaurantRepository
    private lateinit var photoStorage: FakeRestaurantPhotoStorage

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        repository = FakeRestaurantRepository()
        photoStorage = FakeRestaurantPhotoStorage()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun TestScope.observeState(viewModel: RestaurantEditViewModel) {
        backgroundScope.launch(dispatcher) { viewModel.uiState.collect {} }
    }

    // --- add mode -------------------------------------------------------

    @Test
    fun `add mode starts blank and not loading`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals("", state.name)
        assertNull(state.cuisineType)
    }

    @Test
    fun `saving without a name flags the name field and does not insert`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        viewModel.onCuisineChange("mediterranean")
        var saved = false

        viewModel.onSave(onSaved = { saved = true })

        assertFalse(saved)
        assertTrue(viewModel.uiState.value.nameError)
        assertNull(repository.lastInserted)
    }

    @Test
    fun `saving without a cuisine flags the cuisine field and does not insert`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        viewModel.onNameChange("Cal Ferran")
        var saved = false

        viewModel.onSave(onSaved = { saved = true })

        assertFalse(saved)
        assertTrue(viewModel.uiState.value.cuisineError)
        assertNull(repository.lastInserted)
    }

    @Test
    fun `an invalid website is flagged instead of silently dropped`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        viewModel.onNameChange("Cal Ferran")
        viewModel.onCuisineChange("mediterranean")
        viewModel.onWebsiteChange("javascript:alert(1)")

        viewModel.onSave(onSaved = {})

        assertTrue(viewModel.uiState.value.websiteError)
        assertNull(repository.lastInserted)
    }

    @Test
    fun `an invalid instagram handle is flagged instead of silently dropped`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        viewModel.onNameChange("Cal Ferran")
        viewModel.onCuisineChange("mediterranean")
        viewModel.onInstagramChange("not a handle!")

        viewModel.onSave(onSaved = {})

        assertTrue(viewModel.uiState.value.instagramError)
        assertNull(repository.lastInserted)
    }

    @Test
    fun `saving valid data inserts a new restaurant and calls back`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        viewModel.onNameChange("  Cal Ferran  ")
        viewModel.onCuisineChange("mediterranean")
        viewModel.onStreetAddressChange("Rambla 1")
        viewModel.onPriceRangeChange(2)
        viewModel.onWebsiteChange("example.com")
        viewModel.onInstagramChange("@cal_ferran")
        var saved = false

        viewModel.onSave(onSaved = { saved = true })

        assertTrue(saved)
        val inserted = repository.lastInserted
        assertEquals("Cal Ferran", inserted?.name)
        assertEquals("mediterranean", inserted?.cuisineType)
        assertEquals(2, inserted?.priceRange)
        assertEquals("https://example.com", inserted?.website)
        assertEquals("cal_ferran", inserted?.instagram)
    }

    @Test
    fun `saving passes trimmed city, region and country through, and leaves them null when blank`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        viewModel.onNameChange("Cal Ferran")
        viewModel.onCuisineChange("mediterranean")
        viewModel.onCityChange("  Girona  ")
        viewModel.onRegionChange("  Girona (província)  ")
        viewModel.onCountryChange("  Spain  ")

        viewModel.onSave(onSaved = {})

        val inserted = repository.lastInserted
        assertEquals("Girona", inserted?.city)
        assertEquals("Girona (província)", inserted?.region)
        assertEquals("Spain", inserted?.country)
    }

    @Test
    fun `saving with city, region and country left blank saves without error`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        viewModel.onNameChange("Cal Ferran")
        viewModel.onCuisineChange("mediterranean")
        var saved = false

        viewModel.onSave(onSaved = { saved = true })

        assertTrue(saved)
        assertNull(repository.lastInserted?.city)
        assertNull(repository.lastInserted?.region)
        assertNull(repository.lastInserted?.country)
    }

    @Test
    fun `citySuggestions, regionSuggestions and countrySuggestions come from the repository`() = runTest {
        repository.cities.value = listOf("Girona", "Barcelona")
        repository.regions.value = listOf("Girona (província)")
        repository.countries.value = listOf("Spain", "France")
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        backgroundScope.launch(dispatcher) { viewModel.citySuggestions.collect {} }
        backgroundScope.launch(dispatcher) { viewModel.regionSuggestions.collect {} }
        backgroundScope.launch(dispatcher) { viewModel.countrySuggestions.collect {} }

        assertEquals(listOf("Girona", "Barcelona"), viewModel.citySuggestions.value)
        assertEquals(listOf("Girona (província)"), viewModel.regionSuggestions.value)
        assertEquals(listOf("Spain", "France"), viewModel.countrySuggestions.value)
    }

    // --- tags (F-59) --------------------------------------------------------

    @Test
    fun `onAddTag appends a trimmed tag`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)

        viewModel.onAddTag("  Terraza  ")

        assertEquals(listOf("Terraza"), viewModel.uiState.value.tags)
    }

    @Test
    fun `onAddTag ignores a tag that fails validation`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)

        viewModel.onAddTag("has,a,comma")

        assertEquals(emptyList<String>(), viewModel.uiState.value.tags)
    }

    @Test
    fun `onAddTag is a no-op for a tag already added, case-insensitively`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        viewModel.onAddTag("Terraza")

        viewModel.onAddTag("terraza")

        assertEquals(listOf("Terraza"), viewModel.uiState.value.tags)
    }

    @Test
    fun `onRemoveTag removes just the matching tag`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        viewModel.onAddTag("Terraza")
        viewModel.onAddTag("Brunch")

        viewModel.onRemoveTag("Terraza")

        assertEquals(listOf("Brunch"), viewModel.uiState.value.tags)
    }

    @Test
    fun `saving passes the current tags to insert`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle())
        observeState(viewModel)
        viewModel.onNameChange("Cal Ferran")
        viewModel.onCuisineChange("mediterranean")
        viewModel.onAddTag("Terraza")

        viewModel.onSave(onSaved = {})

        assertEquals(listOf("Terraza"), repository.lastSavedTags)
    }

    // --- edit mode --------------------------------------------------------

    @Test
    fun `edit mode loads the existing restaurant into the form`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(
                id = "1", name = "Cal Ferran", cuisineType = "mediterranean", streetAddress = "Rambla 1",
                city = "Girona", region = "Girona (província)", country = "Spain", priceRange = 2
            )
        )
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle(mapOf("restaurantId" to "1")))
        observeState(viewModel)

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals("Cal Ferran", state.name)
        assertEquals("mediterranean", state.cuisineType)
        assertEquals("Rambla 1", state.streetAddress)
        assertEquals("Girona", state.city)
        assertEquals("Girona (província)", state.region)
        assertEquals("Spain", state.country)
    }

    @Test
    fun `edit mode loads the existing restaurant's tags into the form`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = "1", name = "Cal Ferran", cuisineType = "mediterranean", streetAddress = null, priceRange = 2)
        )
        repository.tagsByRestaurantId.value = mapOf("1" to listOf("Terraza", "Brunch"))
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle(mapOf("restaurantId" to "1")))
        observeState(viewModel)

        assertEquals(listOf("Terraza", "Brunch"), viewModel.uiState.value.tags)
    }

    @Test
    fun `saving in edit mode updates rather than inserts`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = "1", name = "Old Name", cuisineType = "mediterranean", streetAddress = null, priceRange = 1)
        )
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle(mapOf("restaurantId" to "1")))
        observeState(viewModel)
        viewModel.onNameChange("New Name")
        var saved = false

        viewModel.onSave(onSaved = { saved = true })

        assertTrue(saved)
        assertNull(repository.lastInserted)
        assertEquals("New Name", repository.lastUpdated?.name)
        assertEquals("1", repository.lastUpdated?.id)
    }

    @Test
    fun `saving in edit mode passes the current tags to update`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = "1", name = "Cal Ferran", cuisineType = "mediterranean", streetAddress = null, priceRange = 1)
        )
        repository.tagsByRestaurantId.value = mapOf("1" to listOf("Terraza"))
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle(mapOf("restaurantId" to "1")))
        observeState(viewModel)
        viewModel.onRemoveTag("Terraza")
        viewModel.onAddTag("Brunch")

        viewModel.onSave(onSaved = {})

        assertEquals(listOf("Brunch"), repository.lastSavedTags)
    }

    // --- photos (F-63) --------------------------------------------------
    //
    // Cases that need an actual android.net.Uri (a pending pick) live in
    // RestaurantEditViewModelPhotoTest instead: Uri isn't mockable in a plain
    // JVM test, and Robolectric is what this codebase already reaches for
    // when a real Android type is unavoidable (see RestaurantDaoTest).

    @Test
    fun `edit mode loads the existing restaurant's photos into the carousel`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = "1", name = "Cal Ferran", cuisineType = "mediterranean", streetAddress = null, priceRange = 1)
        )
        repository.photosByRestaurantId["1"] =
            listOf(Photo(id = "p1", restaurantId = "1", path = "/existing/photo.jpg", position = 0))
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle(mapOf("restaurantId" to "1")))
        observeState(viewModel)

        assertEquals(listOf("/existing/photo.jpg"), viewModel.uiState.value.photoPaths)
    }

    @Test
    fun `onRemovePhoto hides an existing photo from the carousel without deleting it yet`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = "1", name = "Cal Ferran", cuisineType = "mediterranean", streetAddress = null, priceRange = 1)
        )
        repository.photosByRestaurantId["1"] =
            listOf(Photo(id = "p1", restaurantId = "1", path = "/existing/photo.jpg", position = 0))
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle(mapOf("restaurantId" to "1")))
        observeState(viewModel)

        viewModel.onRemovePhoto("/existing/photo.jpg")

        assertEquals(emptyList<String>(), viewModel.uiState.value.photoPaths)
        assertNull(repository.lastDeletedPhotoId)
    }

    @Test
    fun `removing an existing photo and saving deletes it`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = "1", name = "Cal Ferran", cuisineType = "mediterranean", streetAddress = null, priceRange = 1)
        )
        repository.photosByRestaurantId["1"] =
            listOf(Photo(id = "p1", restaurantId = "1", path = "/existing/photo.jpg", position = 0))
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle(mapOf("restaurantId" to "1")))
        observeState(viewModel)
        viewModel.onRemovePhoto("/existing/photo.jpg")

        viewModel.onSave(onSaved = {})

        assertEquals("p1", repository.lastDeletedPhotoId)
    }

    @Test
    fun `saving without touching photos keeps the ones already stored`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = "1", name = "Old Name", cuisineType = "mediterranean", streetAddress = null, priceRange = 1)
        )
        repository.photosByRestaurantId["1"] =
            listOf(Photo(id = "p1", restaurantId = "1", path = "/existing/photo.jpg", position = 0))
        val viewModel = RestaurantEditViewModel(repository, photoStorage, SavedStateHandle(mapOf("restaurantId" to "1")))
        observeState(viewModel)
        viewModel.onNameChange("New Name")

        viewModel.onSave(onSaved = {})

        assertNull(repository.lastDeletedPhotoId)
        assertEquals(listOf("/existing/photo.jpg"), viewModel.uiState.value.photoPaths)
    }
}

internal class FakeRestaurantRepository : RestaurantRepository {

    val restaurants = MutableStateFlow<List<Restaurant>>(emptyList())
    val tagsByRestaurantId = MutableStateFlow<Map<String, List<String>>>(emptyMap())
    val allTagNames = MutableStateFlow<List<String>>(emptyList())
    val cities = MutableStateFlow<List<String>>(emptyList())
    val regions = MutableStateFlow<List<String>>(emptyList())
    val countries = MutableStateFlow<List<String>>(emptyList())
    val latestVisitByRestaurantId = MutableStateFlow<Map<String, Visit>>(emptyMap())
    val photosByRestaurantId = mutableMapOf<String, List<Photo>>()

    var lastInserted: Restaurant? = null
        private set
    var lastUpdated: Restaurant? = null
        private set
    var lastSavedTags: List<String>? = null
        private set
    /** (restaurantId, visited, rating) from the last [saveSingleVisit] call. */
    var lastSingleVisit: Triple<String, Boolean, Int>? = null
        private set
    var lastSingleVisitNotes: String? = null
        private set
    var lastAddedRestaurantPhotos: Pair<String, List<String>>? = null
        private set
    var lastDeletedPhotoId: String? = null
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
    ): Flow<List<Restaurant>> = restaurants

    override fun observeCuisineTypes(): Flow<List<String>> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeCities(): Flow<List<String>> = cities

    override fun observeRegions(): Flow<List<String>> = regions

    override fun observeCountries(): Flow<List<String>> = countries

    override fun observeById(id: String): Flow<Restaurant?> =
        restaurants.map { list -> list.firstOrNull { it.id == id } }

    override suspend fun insert(restaurant: Restaurant, tags: List<String>) {
        lastInserted = restaurant
        lastSavedTags = tags
        restaurants.value = restaurants.value + restaurant
    }

    override suspend fun update(restaurant: Restaurant, tags: List<String>) {
        lastUpdated = restaurant
        lastSavedTags = tags
    }

    override suspend fun delete(id: String) =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override suspend fun deleteAll() =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeAllTagNames(): Flow<List<String>> = allTagNames

    override fun observeTagNames(restaurantId: String): Flow<List<String>> =
        tagsByRestaurantId.map { it[restaurantId].orEmpty() }

    override fun observeTagsByRestaurantId(): Flow<Map<String, List<String>>> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeTotalCount(): Flow<Int> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeVisitedCount(): Flow<Int> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeAverageRating(): Flow<Double?> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeCuisineCounts(): Flow<List<CuisineCount>> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observePriceRangeCounts(): Flow<List<PriceRangeCount>> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeTagCounts(): Flow<List<com.saatxi.eatapp.data.local.TagCount>> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeAllVisitDates(): Flow<List<Long>> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeAllVisitDateRatings(): Flow<List<com.saatxi.eatapp.data.local.VisitDateRating>> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override suspend fun getRandomWantToTry(): Restaurant? =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeVisitsForRestaurant(restaurantId: String): Flow<List<Visit>> =
        latestVisitByRestaurantId.map { listOfNotNull(it[restaurantId]) }

    override fun observeLatestVisitByRestaurantId(): Flow<Map<String, Visit>> = latestVisitByRestaurantId

    override suspend fun getLatestVisit(restaurantId: String): Visit? = latestVisitByRestaurantId.value[restaurantId]

    override suspend fun saveSingleVisit(restaurantId: String, visited: Boolean, rating: Int, notes: String?) {
        lastSingleVisit = Triple(restaurantId, visited, rating)
        lastSingleVisitNotes = notes
    }

    override suspend fun addVisit(restaurantId: String, visitDate: Long, rating: Int, notes: String?, priceRange: Int) =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override suspend fun addVisit(
        restaurantId: String,
        visitDate: Long,
        rating: Int,
        notes: String?,
        priceRange: Int,
        photoPaths: List<String>
    ): String =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override suspend fun deleteVisit(id: String) =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observePhotosForRestaurant(restaurantId: String): Flow<List<Photo>> =
        MutableStateFlow(photosByRestaurantId[restaurantId].orEmpty())

    override fun observePhotosForVisit(visitId: String): Flow<List<Photo>> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override suspend fun getRestaurantPhotoPath(restaurantId: String): String? =
        photosByRestaurantId[restaurantId]?.firstOrNull()?.path

    override suspend fun addRestaurantPhotos(restaurantId: String, photoPaths: List<String>) {
        lastAddedRestaurantPhotos = restaurantId to photoPaths
    }

    override suspend fun deletePhoto(id: String) {
        lastDeletedPhotoId = id
    }
}

internal class FakeRestaurantPhotoStorage : RestaurantPhotoStorage {
    /** What [copy] should hand back on its next call; null simulates a failed copy. */
    var nextCopyResult: String? = "/fake/photos/copied.jpg"
    var lastCopiedSource: Uri? = null
        private set

    override suspend fun copy(source: Uri): String? {
        lastCopiedSource = source
        return nextCopyResult
    }
}
