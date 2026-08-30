package com.saatxi.eatapp.ui.edit

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
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

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        repository = FakeRestaurantRepository()
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
        val viewModel = RestaurantEditViewModel(repository, restaurantId = null)
        observeState(viewModel)

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals("", state.name)
        assertNull(state.cuisineType)
    }

    @Test
    fun `saving without a name flags the name field and does not insert`() = runTest {
        val viewModel = RestaurantEditViewModel(repository, restaurantId = null)
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
        val viewModel = RestaurantEditViewModel(repository, restaurantId = null)
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
        val viewModel = RestaurantEditViewModel(repository, restaurantId = null)
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
        val viewModel = RestaurantEditViewModel(repository, restaurantId = null)
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
        val viewModel = RestaurantEditViewModel(repository, restaurantId = null)
        observeState(viewModel)
        viewModel.onNameChange("  Cal Ferran  ")
        viewModel.onCuisineChange("mediterranean")
        viewModel.onAddressChange("Rambla 1")
        viewModel.onRatingChange(4)
        viewModel.onPriceRangeChange(2)
        viewModel.onWebsiteChange("example.com")
        viewModel.onInstagramChange("@cal_ferran")
        var saved = false

        viewModel.onSave(onSaved = { saved = true })

        assertTrue(saved)
        val inserted = repository.lastInserted
        assertEquals("Cal Ferran", inserted?.name)
        assertEquals("mediterranean", inserted?.cuisineType)
        assertEquals(4, inserted?.rating)
        assertEquals(2, inserted?.priceRange)
        assertEquals("https://example.com", inserted?.website)
        assertEquals("cal_ferran", inserted?.instagram)
        assertEquals(0L, inserted?.id)
    }

    // --- edit mode --------------------------------------------------------

    @Test
    fun `edit mode loads the existing restaurant into the form`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = 1, name = "Cal Ferran", cuisineType = "mediterranean", address = "Rambla 1", rating = 4, priceRange = 2)
        )
        val viewModel = RestaurantEditViewModel(repository, restaurantId = 1L)
        observeState(viewModel)

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals("Cal Ferran", state.name)
        assertEquals("mediterranean", state.cuisineType)
        assertEquals(4, state.rating)
    }

    @Test
    fun `saving in edit mode updates rather than inserts`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = 1, name = "Old Name", cuisineType = "mediterranean", address = null, rating = 3, priceRange = 1)
        )
        val viewModel = RestaurantEditViewModel(repository, restaurantId = 1L)
        observeState(viewModel)
        viewModel.onNameChange("New Name")
        var saved = false

        viewModel.onSave(onSaved = { saved = true })

        assertTrue(saved)
        assertNull(repository.lastInserted)
        assertEquals("New Name", repository.lastUpdated?.name)
        assertEquals(1L, repository.lastUpdated?.id)
    }
}

private class FakeRestaurantRepository : RestaurantRepository {

    val restaurants = MutableStateFlow<List<Restaurant>>(emptyList())

    var lastInserted: Restaurant? = null
        private set
    var lastUpdated: Restaurant? = null
        private set

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort
    ): Flow<List<Restaurant>> = restaurants

    override fun observeCuisineTypes(): Flow<List<String>> =
        throw NotImplementedError("Not used by RestaurantEditViewModel")

    override fun observeById(id: Long): Flow<Restaurant?> =
        restaurants.map { list -> list.firstOrNull { it.id == id } }

    override suspend fun insert(restaurant: Restaurant): Long {
        lastInserted = restaurant
        return 1L
    }

    override suspend fun update(restaurant: Restaurant) {
        lastUpdated = restaurant
    }

    override suspend fun delete(id: Long) =
        throw NotImplementedError("Not used by RestaurantEditViewModel")
}
