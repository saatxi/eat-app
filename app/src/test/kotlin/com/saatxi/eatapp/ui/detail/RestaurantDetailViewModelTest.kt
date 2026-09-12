package com.saatxi.eatapp.ui.detail

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.Visit
import com.saatxi.eatapp.data.prefs.FakeUserPreferencesRepository
import com.saatxi.eatapp.data.prefs.UserPreferences
import com.saatxi.eatapp.data.repository.FakeRestaurantRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class RestaurantDetailViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var repository: FakeRestaurantRepository
    private lateinit var preferencesRepository: FakeUserPreferencesRepository
    private lateinit var viewModel: RestaurantDetailViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        repository = FakeRestaurantRepository()
        preferencesRepository = FakeUserPreferencesRepository()
        viewModel = RestaurantDetailViewModel(
            repository = repository,
            preferencesRepository = preferencesRepository,
            restaurantId = "1"
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun TestScope.observeState() {
        backgroundScope.launch(dispatcher) { viewModel.uiState.collect {} }
    }

    @Test
    fun `starts loading`() = runTest {
        assertEquals(DetailUiState.Loading, viewModel.uiState.value)
    }

    @Test
    fun `reports not found when the repository has no matching restaurant`() = runTest {
        observeState()

        assertEquals(DetailUiState.NotFound, viewModel.uiState.value)
    }

    @Test
    fun `loads the restaurant with isFavorite false when its id is not favourited`() = runTest {
        observeState()

        repository.restaurants.value = listOf(restaurant("1"))

        val state = viewModel.uiState.value as DetailUiState.Loaded
        assertEquals("1", state.restaurant.id)
        assertFalse(state.restaurant.isFavorite)
    }

    @Test
    fun `loads the restaurant with isFavorite true when its id is favourited`() = runTest {
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf("1"))
        observeState()

        repository.restaurants.value = listOf(restaurant("1"))

        val state = viewModel.uiState.value as DetailUiState.Loaded
        assertTrue(state.restaurant.isFavorite)
    }

    @Test
    fun `loads the restaurant's tags as a comma-joined label`() = runTest {
        observeState()
        repository.tagsByRestaurantId.value = mapOf("1" to listOf("Terraza", "Brunch"))

        repository.restaurants.value = listOf(restaurant("1"))

        val state = viewModel.uiState.value as DetailUiState.Loaded
        assertEquals("Terraza, Brunch", state.restaurant.tagsLabel)
    }

    @Test
    fun `loads the restaurant's latest visit as its rating`() = runTest {
        observeState()
        repository.latestVisitByRestaurantId.value = mapOf("1" to Visit(id = "v", restaurantId = "1", visitDate = 0L, rating = 4))

        repository.restaurants.value = listOf(restaurant("1"))

        val state = viewModel.uiState.value as DetailUiState.Loaded
        assertEquals(4, state.restaurant.rating)
        assertTrue(state.restaurant.visited)
    }

    @Test
    fun `onFavoriteToggle toggles this restaurant's own id`() = runTest {
        observeState()
        repository.restaurants.value = listOf(restaurant("1"))

        viewModel.onFavoriteToggle()

        assertEquals(setOf("1"), preferencesRepository.preferences.value.favoriteIds)

        viewModel.onFavoriteToggle()

        assertEquals(emptySet<String>(), preferencesRepository.preferences.value.favoriteIds)
    }

    @Test
    fun `onDelete removes the restaurant and calls back once done`() = runTest {
        observeState()
        repository.restaurants.value = listOf(restaurant("1"))
        var deleted = false

        viewModel.onDelete(onDeleted = { deleted = true })

        assertTrue(deleted)
        assertEquals(emptyList<Restaurant>(), repository.restaurants.value)
    }

    private fun restaurant(id: String) = Restaurant(
        id = id,
        name = "Cal Ferran",
        cuisineType = "mediterranean",
        streetAddress = null,
        priceRange = 2
    )
}
