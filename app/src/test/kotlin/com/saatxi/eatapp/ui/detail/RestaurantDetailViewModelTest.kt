package com.saatxi.eatapp.ui.detail

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.prefs.UserPreferences
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.ThemeMode
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
            restaurantId = 1L
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

        repository.restaurants.value = listOf(restaurant(1))

        val state = viewModel.uiState.value as DetailUiState.Loaded
        assertEquals(1L, state.restaurant.id)
        assertFalse(state.restaurant.isFavorite)
    }

    @Test
    fun `loads the restaurant with isFavorite true when its id is favourited`() = runTest {
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf(1L))
        observeState()

        repository.restaurants.value = listOf(restaurant(1))

        val state = viewModel.uiState.value as DetailUiState.Loaded
        assertTrue(state.restaurant.isFavorite)
    }

    @Test
    fun `onFavoriteToggle toggles this restaurant's own id`() = runTest {
        observeState()
        repository.restaurants.value = listOf(restaurant(1))

        viewModel.onFavoriteToggle()

        assertEquals(setOf(1L), preferencesRepository.preferences.value.favoriteIds)

        viewModel.onFavoriteToggle()

        assertEquals(emptySet<Long>(), preferencesRepository.preferences.value.favoriteIds)
    }

    @Test
    fun `onDelete removes the restaurant and calls back once done`() = runTest {
        observeState()
        repository.restaurants.value = listOf(restaurant(1))
        var deleted = false

        viewModel.onDelete(onDeleted = { deleted = true })

        assertTrue(deleted)
        assertEquals(emptyList<Restaurant>(), repository.restaurants.value)
    }

    private fun restaurant(id: Long) = Restaurant(
        id = id,
        name = "Cal Ferran",
        cuisineType = "mediterranean",
        address = null,
        rating = 4,
        priceRange = 2
    )
}

private class FakeRestaurantRepository : RestaurantRepository {

    val restaurants = MutableStateFlow<List<Restaurant>>(emptyList())

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort
    ): Flow<List<Restaurant>> = restaurants

    override fun observeCuisineTypes(): Flow<List<String>> = restaurants.map { list -> list.map { it.cuisineType } }

    override fun observeById(id: Long): Flow<Restaurant?> =
        restaurants.map { list -> list.firstOrNull { it.id == id } }

    override suspend fun insert(restaurant: Restaurant): Long =
        throw NotImplementedError("Not used by RestaurantDetailViewModel")

    override suspend fun update(restaurant: Restaurant) =
        throw NotImplementedError("Not used by RestaurantDetailViewModel")

    override suspend fun delete(id: Long) {
        restaurants.value = restaurants.value.filterNot { it.id == id }
    }

    override suspend fun deleteAll() {
        restaurants.value = emptyList()
    }
}

private class FakeUserPreferencesRepository : UserPreferencesRepository {

    override val preferences = MutableStateFlow(UserPreferences.Defaults)

    override suspend fun setPalette(palette: AppPalette) {
        preferences.value = preferences.value.copy(palette = palette)
    }

    override suspend fun setThemeMode(themeMode: ThemeMode) {
        preferences.value = preferences.value.copy(themeMode = themeMode)
    }

    override suspend fun toggleFavorite(restaurantId: Long) {
        val current = preferences.value.favoriteIds
        preferences.value = preferences.value.copy(
            favoriteIds = if (restaurantId in current) current - restaurantId else current + restaurantId
        )
    }
}
