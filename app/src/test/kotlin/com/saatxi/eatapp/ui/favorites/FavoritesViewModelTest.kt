package com.saatxi.eatapp.ui.favorites

import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.prefs.UserPreferences
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.ThemeMode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
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
class FavoritesViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var repository: FakeRestaurantRepository
    private lateinit var preferencesRepository: FakeUserPreferencesRepository
    private lateinit var viewModel: FavoritesViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        repository = FakeRestaurantRepository()
        preferencesRepository = FakeUserPreferencesRepository()
        viewModel = FavoritesViewModel(repository, preferencesRepository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun TestScope.observeState() {
        backgroundScope.launch(dispatcher) { viewModel.uiState.collect {} }
    }

    @Test
    fun `starts empty`() = runTest {
        observeState()

        assertEquals(emptyList<Any>(), viewModel.uiState.value.restaurants)
        assertFalse(viewModel.uiState.value.isInitialLoad)
    }

    @Test
    fun `only favourited restaurants reach the state, each marked isFavorite`() = runTest {
        observeState()
        repository.restaurants.value = listOf(
            restaurant(1, "Cal Ferran"),
            restaurant(2, "Bar Nil"),
            restaurant(3, "Sushi Kobe")
        )

        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf(1L, 3L))

        val result = viewModel.uiState.value.restaurants
        assertEquals(setOf(1L, 3L), result.map { it.id }.toSet())
        assertTrue(result.all { it.isFavorite })
    }

    @Test
    fun `un-favouriting a restaurant removes it from the state`() = runTest {
        observeState()
        repository.restaurants.value = listOf(restaurant(1, "Cal Ferran"))
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf(1L))
        assertEquals(1, viewModel.uiState.value.restaurants.size)

        viewModel.onFavoriteToggle(1L)

        assertEquals(emptyList<Any>(), viewModel.uiState.value.restaurants)
    }

    private fun restaurant(id: Long, name: String) = Restaurant(
        id = id,
        name = name,
        cuisineType = "mediterranean",
        address = null,
        rating = 3,
        priceRange = 2
    )
}

private class FakeRestaurantRepository : RestaurantRepository {

    val restaurants = MutableStateFlow<List<Restaurant>>(emptyList())

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort,
        visited: Boolean?
    ): Flow<List<Restaurant>> = restaurants

    override fun observeCuisineTypes(): Flow<List<String>> =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override fun observeById(id: Long): Flow<Restaurant?> =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override suspend fun insert(restaurant: Restaurant): Long =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override suspend fun update(restaurant: Restaurant) =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override suspend fun delete(id: Long) =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override suspend fun deleteAll() =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override fun observeTotalCount(): Flow<Int> =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override fun observeVisitedCount(): Flow<Int> =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override fun observeAverageRating(): Flow<Double?> =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override fun observeCuisineCounts(): Flow<List<CuisineCount>> =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override fun observePriceRangeCounts(): Flow<List<PriceRangeCount>> =
        throw NotImplementedError("Not used by FavoritesViewModel")
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
