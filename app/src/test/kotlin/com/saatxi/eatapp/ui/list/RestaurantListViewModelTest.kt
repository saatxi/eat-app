package com.saatxi.eatapp.ui.list

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.prefs.UserPreferences
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.FakeRestaurantRepository
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.ThemeMode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.TestScope
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
 * The ViewModel's job here is wiring: turning three independent filter inputs
 * into one repository query and one UI state. The filtering itself belongs to
 * the DAO and is covered by RestaurantDaoTest.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RestaurantListViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var repository: FakeRestaurantRepository
    private lateinit var preferencesRepository: FakeUserPreferencesRepository
    private lateinit var viewModel: RestaurantListViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        repository = FakeRestaurantRepository()
        preferencesRepository = FakeUserPreferencesRepository()
        viewModel = RestaurantListViewModel(
            repository = repository,
            preferencesRepository = preferencesRepository
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    /** uiState is a WhileSubscribed flow, so it only updates while collected. */
    private fun TestScope.observeState() {
        backgroundScope.launch(dispatcher) { viewModel.uiState.collect {} }
    }

    /** A non-blank search query is debounced by 250ms before reaching the repository, per F-16. */
    private fun advanceSearchDebounce() {
        dispatcher.scheduler.advanceUntilIdle()
    }

    // --- initial state ------------------------------------------------------

    @Test
    fun `starts empty, with no filter`() = runTest {
        observeState()

        val state = viewModel.uiState.value
        assertEquals("", state.searchQuery)
        assertNull(state.minRating)
        assertNull(state.cuisineType)
        assertEquals(emptyList<RestaurantUiModel>(), state.restaurants)
        assertFalse(state.hasActiveFilter)
    }

    // --- F-20: the initial-load flag ---------------------------------------

    @Test
    fun `starts in the initial-load state, before the database has emitted`() = runTest {
        assertTrue(viewModel.uiState.value.isInitialLoad)
    }

    @Test
    fun `the initial-load flag clears on the first emission, even an empty one`() = runTest {
        observeState()

        assertFalse(viewModel.uiState.value.isInitialLoad)
        assertEquals(emptyList<RestaurantUiModel>(), viewModel.uiState.value.restaurants)
    }

    // --- filters reach the repository and the state -------------------------

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
    fun `the three filters are applied together, not one at a time`() = runTest {
        observeState()

        viewModel.onSearchQueryChange("sushi")
        viewModel.onMinRatingChange(4)
        viewModel.onCuisineChange("japanese")
        advanceSearchDebounce()

        assertEquals("sushi", repository.lastQuery)
        assertEquals(4, repository.lastMinRating)
        assertEquals("japanese", repository.lastCuisine)
    }

    @Test
    fun `selecting a filter and then clearing it returns to no filter`() = runTest {
        observeState()

        viewModel.onCuisineChange("japanese")
        viewModel.onCuisineChange(null)

        assertNull(viewModel.uiState.value.cuisineType)
        assertNull(repository.lastCuisine)
    }

    @Test
    fun `clearFilters resets all three at once`() = runTest {
        observeState()
        viewModel.onSearchQueryChange("sushi")
        viewModel.onMinRatingChange(4)
        viewModel.onCuisineChange("japanese")

        viewModel.clearFilters()

        val state = viewModel.uiState.value
        assertEquals("", state.searchQuery)
        assertNull(state.minRating)
        assertNull(state.cuisineType)
        assertFalse(state.hasActiveFilter)
    }

    // --- location filters (poble/regió/país) --------------------------------

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
    fun `available cities, regions and countries reach the state`() = runTest {
        observeState()

        repository.cities.value = listOf("Girona", "Barcelona")
        repository.regions.value = listOf("Girona (província)")
        repository.countries.value = listOf("Spain", "France")

        assertEquals(listOf("Girona", "Barcelona"), viewModel.uiState.value.availableCities)
        assertEquals(listOf("Girona (província)"), viewModel.uiState.value.availableRegions)
        assertEquals(listOf("Spain", "France"), viewModel.uiState.value.availableCountries)
    }

    @Test
    fun `clearFilters also resets city, region and country`() = runTest {
        observeState()
        viewModel.onCityChange("Girona")
        viewModel.onRegionChange("Girona (província)")
        viewModel.onCountryChange("Spain")

        viewModel.clearFilters()

        val state = viewModel.uiState.value
        assertNull(state.city)
        assertNull(state.region)
        assertNull(state.country)
        assertFalse(state.hasActiveFilter)
    }

    // --- visit status filter -------------------------------------------------

    @Test
    fun `a visited filter lands in the state and in the query`() = runTest {
        observeState()

        viewModel.onVisitedChange(false)

        assertEquals(false, viewModel.uiState.value.visited)
        assertEquals(false, repository.lastVisited)
        assertTrue(viewModel.uiState.value.hasActiveFilter)
    }

    @Test
    fun `clearFilters also resets the visited filter`() = runTest {
        observeState()
        viewModel.onVisitedChange(true)

        viewModel.clearFilters()

        assertNull(viewModel.uiState.value.visited)
        assertFalse(viewModel.uiState.value.hasActiveFilter)
    }

    // --- hasActiveFilter, which drives the "Clear filters" empty state ------

    @Test
    fun `hasActiveFilter is true for any single filter`() = runTest {
        observeState()

        viewModel.onSearchQueryChange("a")
        assertTrue(viewModel.uiState.value.hasActiveFilter)
        viewModel.clearFilters()

        viewModel.onMinRatingChange(2)
        assertTrue(viewModel.uiState.value.hasActiveFilter)
        viewModel.clearFilters()

        viewModel.onCuisineChange("bar")
        assertTrue(viewModel.uiState.value.hasActiveFilter)
    }

    @Test
    fun `a whitespace-only query does not count as an active filter`() = runTest {
        observeState()

        viewModel.onSearchQueryChange("   ")

        assertFalse(viewModel.uiState.value.hasActiveFilter)
    }

    // --- F-29: sort order ---------------------------------------------------

    @Test
    fun `starts sorted by name`() = runTest {
        observeState()

        assertEquals(RestaurantSort.NAME, viewModel.uiState.value.sort)
        assertEquals(RestaurantSort.NAME, repository.lastSort)
    }

    @Test
    fun `a new sort order lands in the state and in the query`() = runTest {
        observeState()

        viewModel.onSortChange(RestaurantSort.RATING)

        assertEquals(RestaurantSort.RATING, viewModel.uiState.value.sort)
        assertEquals(RestaurantSort.RATING, repository.lastSort)
    }

    @Test
    fun `the sort order is not a filter, so it does not make one active`() = runTest {
        observeState()

        viewModel.onSortChange(RestaurantSort.RATING)

        assertFalse(viewModel.uiState.value.hasActiveFilter)
    }

    @Test
    fun `clearFilters keeps the chosen sort order`() = runTest {
        observeState()
        viewModel.onSortChange(RestaurantSort.RATING)
        viewModel.onSearchQueryChange("sushi")

        viewModel.clearFilters()

        assertEquals(RestaurantSort.RATING, viewModel.uiState.value.sort)
        assertEquals(RestaurantSort.RATING, repository.lastSort)
    }

    // --- data flowing the other way ----------------------------------------

    @Test
    fun `restaurants from the repository reach the state`() = runTest {
        observeState()

        repository.restaurants.value = listOf(restaurant("1", "Cal Ferran"), restaurant("2", "Bar Nil"))

        assertEquals(listOf("Cal Ferran", "Bar Nil"), viewModel.uiState.value.restaurants.map { it.name })
    }

    @Test
    fun `entities are mapped to UI models before reaching the state`() = runTest {
        observeState()

        repository.restaurants.value = listOf(restaurant("1", "Cal Ferran"))

        val item = viewModel.uiState.value.restaurants.single()
        assertEquals("1", item.id)
        assertEquals("mediterranean", item.cuisineKey)
        assertEquals("$$", item.priceLabel)
    }

    @Test
    fun `each restaurant's tags reach the state as a comma-joined label`() = runTest {
        observeState()
        repository.tagsByRestaurantId.value = mapOf("1" to listOf("Terraza", "Brunch"))

        repository.restaurants.value = listOf(restaurant("1", "Cal Ferran"), restaurant("2", "Bar Nil"))

        val items = viewModel.uiState.value.restaurants.associateBy { it.id }
        assertEquals("Terraza, Brunch", items.getValue("1").tagsLabel)
        assertEquals("", items.getValue("2").tagsLabel)
    }

    @Test
    fun `available cuisines reach the state`() = runTest {
        observeState()

        repository.cuisines.value = listOf("japanese", "seafood")

        assertEquals(listOf("japanese", "seafood"), viewModel.uiState.value.availableCuisines)
    }

    @Test
    fun `a later emission replaces the previous list`() = runTest {
        observeState()
        repository.restaurants.value = listOf(restaurant("1", "Old"))

        repository.restaurants.value = listOf(restaurant("2", "New"))

        assertEquals(listOf("New"), viewModel.uiState.value.restaurants.map { it.name })
    }

    private fun restaurant(id: String, name: String) = Restaurant(
        id = id,
        name = name,
        cuisineType = "mediterranean",
        streetAddress = null,
        priceRange = 2
    )

    // --- Phase 3: favourites ------------------------------------------------

    @Test
    fun `a restaurant whose id is in favoriteIds maps to isFavorite true`() = runTest {
        observeState()
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf("1"))

        repository.restaurants.value = listOf(restaurant("1", "Cal Ferran"), restaurant("2", "Bar Nil"))

        val items = viewModel.uiState.value.restaurants.associateBy { it.id }
        assertTrue(items.getValue("1").isFavorite)
        assertFalse(items.getValue("2").isFavorite)
    }

    @Test
    fun `onFavoriteToggle writes through to the preferences repository`() = runTest {
        observeState()

        viewModel.onFavoriteToggle("1")

        assertEquals(setOf("1"), preferencesRepository.preferences.value.favoriteIds)
    }

    // --- F-65: swipe-to-delete ------------------------------------------

    @Test
    fun `onDeleteRestaurant deletes the given restaurant through the repository`() = runTest {
        observeState()

        viewModel.onDeleteRestaurant("1")

        assertEquals("1", repository.lastDeletedId)
    }
}

/** Replays whatever the test pushes into [preferences] and records favourite writes. */
private class FakeUserPreferencesRepository : UserPreferencesRepository {

    override val preferences = MutableStateFlow(UserPreferences.Defaults)

    override suspend fun setPalette(palette: AppPalette) {
        preferences.value = preferences.value.copy(palette = palette)
    }

    override suspend fun setThemeMode(themeMode: ThemeMode) {
        preferences.value = preferences.value.copy(themeMode = themeMode)
    }

    override suspend fun toggleFavorite(restaurantId: String) {
        val current = preferences.value.favoriteIds
        preferences.value = preferences.value.copy(
            favoriteIds = if (restaurantId in current) current - restaurantId else current + restaurantId
        )
    }
}
