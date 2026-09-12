package com.saatxi.eatapp.ui.favorites

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
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
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * F-60 gave this ViewModel the exact search/sort/filter shape
 * `RestaurantListViewModelTest` already covers for the main list — this
 * class focuses on what's specific to Favorites (the favourited-ids
 * narrowing, and reusing the same repository query the list screen does)
 * rather than re-proving the filter debounce/reset mechanics themselves.
 */
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

    private fun advanceSearchDebounce() {
        dispatcher.scheduler.advanceUntilIdle()
    }

    @Test
    fun `starts empty, with no filter`() = runTest {
        observeState()

        assertEquals(emptyList<Any>(), viewModel.uiState.value.restaurants)
        assertFalse(viewModel.uiState.value.isInitialLoad)
        assertFalse(viewModel.uiState.value.hasActiveFilter)
    }

    @Test
    fun `only favourited restaurants reach the state, each marked isFavorite`() = runTest {
        observeState()
        repository.restaurants.value = listOf(
            restaurant("1", "Cal Ferran"),
            restaurant("2", "Bar Nil"),
            restaurant("3", "Sushi Kobe")
        )

        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf("1", "3"))

        val result = viewModel.uiState.value.restaurants
        assertEquals(setOf("1", "3"), result.map { it.id }.toSet())
        assertTrue(result.all { it.isFavorite })
    }

    @Test
    fun `un-favouriting a restaurant removes it from the state`() = runTest {
        observeState()
        repository.restaurants.value = listOf(restaurant("1", "Cal Ferran"))
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf("1"))
        assertEquals(1, viewModel.uiState.value.restaurants.size)

        viewModel.onFavoriteToggle("1")

        assertEquals(emptyList<Any>(), viewModel.uiState.value.restaurants)
    }

    @Test
    fun `each favourited restaurant's tags reach the state as a comma-joined label`() = runTest {
        observeState()
        repository.restaurants.value = listOf(restaurant("1", "Cal Ferran"))
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf("1"))
        repository.tagsByRestaurantId.value = mapOf("1" to listOf("Terraza", "Brunch"))

        assertEquals("Terraza, Brunch", viewModel.uiState.value.restaurants.single().tagsLabel)
    }

    @Test
    fun `available cuisines reach the state`() = runTest {
        observeState()

        repository.cuisines.value = listOf("japanese", "seafood")

        assertEquals(listOf("japanese", "seafood"), viewModel.uiState.value.availableCuisines)
    }

    // --- search/sort/filter reach the repository's own observeFiltered query ---

    @Test
    fun `a search query lands in the state immediately, and in the query after the debounce`() = runTest {
        observeState()

        viewModel.onSearchQueryChange("ferran")

        assertEquals("ferran", viewModel.uiState.value.searchQuery)
        assertEquals("", repository.lastQuery)

        advanceSearchDebounce()

        assertEquals("ferran", repository.lastQuery)
    }

    @Test
    fun `a minimum rating lands in the state and in the query`() = runTest {
        observeState()

        viewModel.onMinRatingChange(4)

        assertEquals(4, viewModel.uiState.value.minRating)
        assertEquals(4, repository.lastMinRating)
    }

    @Test
    fun `a cuisine lands in the state and in the query`() = runTest {
        observeState()

        viewModel.onCuisineChange("japanese")

        assertEquals("japanese", viewModel.uiState.value.cuisineType)
        assertEquals("japanese", repository.lastCuisine)
    }

    @Test
    fun `a visited filter lands in the state and in the query`() = runTest {
        observeState()

        viewModel.onVisitedChange(false)

        assertEquals(false, viewModel.uiState.value.visited)
        assertEquals(false, repository.lastVisited)
        assertTrue(viewModel.uiState.value.hasActiveFilter)
    }

    @Test
    fun `a new sort order lands in the state and in the query`() = runTest {
        observeState()

        viewModel.onSortChange(RestaurantSort.RATING)

        assertEquals(RestaurantSort.RATING, viewModel.uiState.value.sort)
        assertEquals(RestaurantSort.RATING, repository.lastSort)
    }

    @Test
    fun `a city lands in the state and in the query`() = runTest {
        observeState()

        viewModel.onCityChange("Girona")

        assertEquals("Girona", viewModel.uiState.value.city)
        assertEquals("Girona", repository.lastCity)
        assertTrue(viewModel.uiState.value.hasActiveFilter)
    }

    @Test
    fun `a region lands in the state and in the query`() = runTest {
        observeState()

        viewModel.onRegionChange("Girona (província)")

        assertEquals("Girona (província)", viewModel.uiState.value.region)
        assertEquals("Girona (província)", repository.lastRegion)
    }

    @Test
    fun `a country lands in the state and in the query`() = runTest {
        observeState()

        viewModel.onCountryChange("Spain")

        assertEquals("Spain", viewModel.uiState.value.country)
        assertEquals("Spain", repository.lastCountry)
    }

    @Test
    fun `availableCities, availableRegions and availableCountries come from the repository`() = runTest {
        repository.cities.value = listOf("Girona", "Barcelona")
        repository.regions.value = listOf("Girona (província)")
        repository.countries.value = listOf("Spain", "France")
        observeState()

        assertEquals(listOf("Girona", "Barcelona"), viewModel.uiState.value.availableCities)
        assertEquals(listOf("Girona (província)"), viewModel.uiState.value.availableRegions)
        assertEquals(listOf("Spain", "France"), viewModel.uiState.value.availableCountries)
    }

    @Test
    fun `clearFilters resets every filter but keeps the chosen sort order`() = runTest {
        observeState()
        viewModel.onSortChange(RestaurantSort.RATING)
        viewModel.onSearchQueryChange("sushi")
        viewModel.onMinRatingChange(4)
        viewModel.onCuisineChange("japanese")
        viewModel.onVisitedChange(true)
        viewModel.onCityChange("Girona")
        viewModel.onRegionChange("Girona (província)")
        viewModel.onCountryChange("Spain")

        viewModel.clearFilters()

        val state = viewModel.uiState.value
        assertEquals("", state.searchQuery)
        assertNull(state.minRating)
        assertNull(state.cuisineType)
        assertNull(state.visited)
        assertNull(state.city)
        assertNull(state.region)
        assertNull(state.country)
        assertEquals(RestaurantSort.RATING, state.sort)
        assertFalse(state.hasActiveFilter)
    }

    // --- F-65: swipe-to-delete ------------------------------------------

    @Test
    fun `onDeleteRestaurant deletes the given restaurant through the repository`() = runTest {
        observeState()

        viewModel.onDeleteRestaurant("1")

        assertEquals("1", repository.lastDeletedId)
    }

    private fun restaurant(id: String, name: String) = Restaurant(
        id = id,
        name = name,
        cuisineType = "mediterranean",
        streetAddress = null,
        priceRange = 2
    )
}
