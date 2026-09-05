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

    @Test
    fun `each favourited restaurant's tags reach the state as a comma-joined label`() = runTest {
        observeState()
        repository.restaurants.value = listOf(restaurant(1, "Cal Ferran"))
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf(1L))
        repository.tagsByRestaurantId.value = mapOf(1L to listOf("Terraza", "Brunch"))

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
    fun `clearFilters resets every filter but keeps the chosen sort order`() = runTest {
        observeState()
        viewModel.onSortChange(RestaurantSort.RATING)
        viewModel.onSearchQueryChange("sushi")
        viewModel.onMinRatingChange(4)
        viewModel.onCuisineChange("japanese")
        viewModel.onVisitedChange(true)

        viewModel.clearFilters()

        val state = viewModel.uiState.value
        assertEquals("", state.searchQuery)
        assertNull(state.minRating)
        assertNull(state.cuisineType)
        assertNull(state.visited)
        assertEquals(RestaurantSort.RATING, state.sort)
        assertFalse(state.hasActiveFilter)
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
    val cuisines = MutableStateFlow<List<String>>(emptyList())
    val tagsByRestaurantId = MutableStateFlow<Map<Long, List<String>>>(emptyMap())

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

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort,
        visited: Boolean?
    ): Flow<List<Restaurant>> {
        lastQuery = query
        lastMinRating = minRating
        lastCuisine = cuisineType
        lastSort = sort
        lastVisited = visited
        return restaurants
    }

    override fun observeCuisineTypes(): Flow<List<String>> = cuisines

    override fun observeById(id: Long): Flow<Restaurant?> =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override suspend fun insert(restaurant: Restaurant, tags: List<String>): Long =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override suspend fun update(restaurant: Restaurant, tags: List<String>) =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override suspend fun delete(id: Long) =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override suspend fun deleteAll() =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override fun observeAllTagNames(): Flow<List<String>> =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override fun observeTagNames(restaurantId: Long): Flow<List<String>> =
        throw NotImplementedError("Not used by FavoritesViewModel")

    override fun observeTagsByRestaurantId(): Flow<Map<Long, List<String>>> = tagsByRestaurantId

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

    override suspend fun getRandomWantToTry(): Restaurant? =
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
