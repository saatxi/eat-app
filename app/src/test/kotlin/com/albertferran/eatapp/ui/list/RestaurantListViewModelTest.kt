package com.albertferran.eatapp.ui.list

import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.local.RestaurantSort
import com.albertferran.eatapp.data.repository.RestaurantRepository
import com.albertferran.eatapp.data.sync.DatabaseSyncManager
import com.albertferran.eatapp.data.sync.DatabaseSyncResult
import com.albertferran.eatapp.ui.model.RestaurantUiModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
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
    private lateinit var syncManager: FakeDatabaseSyncManager
    private lateinit var viewModel: RestaurantListViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        // Non-zero, so the F-08 auto-sync-on-empty behaviour (covered separately
        // below, against its own fresh repository) doesn't fire for every other
        // test in this class.
        repository = FakeRestaurantRepository(count = 1)
        syncManager = FakeDatabaseSyncManager()
        viewModel = RestaurantListViewModel(repository = repository, syncManager = syncManager)
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
    fun `starts empty, with no filter and not syncing`() = runTest {
        observeState()

        val state = viewModel.uiState.value
        assertEquals("", state.searchQuery)
        assertNull(state.minRating)
        assertNull(state.cuisineType)
        assertEquals(emptyList<RestaurantUiModel>(), state.restaurants)
        assertFalse(state.isSyncing)
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

        repository.restaurants.value = listOf(restaurant(1, "Cal Ferran"), restaurant(2, "Bar Nil"))

        assertEquals(listOf("Cal Ferran", "Bar Nil"), viewModel.uiState.value.restaurants.map { it.name })
    }

    @Test
    fun `entities are mapped to UI models before reaching the state`() = runTest {
        observeState()

        repository.restaurants.value = listOf(restaurant(1, "Cal Ferran"))

        val item = viewModel.uiState.value.restaurants.single()
        assertEquals(1L, item.id)
        assertEquals("mediterranean", item.cuisineKey)
        assertEquals("$$", item.priceLabel)
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
        repository.restaurants.value = listOf(restaurant(1, "Old"))

        repository.restaurants.value = listOf(restaurant(2, "New"))

        assertEquals(listOf("New"), viewModel.uiState.value.restaurants.map { it.name })
    }

    private fun restaurant(id: Long, name: String) = Restaurant(
        id = id,
        name = name,
        cuisineType = "mediterranean",
        address = null,
        rating = 3,
        priceRange = 2
    )

    // --- F-08: automatic first sync ------------------------------------------
    // Each test here builds its own ViewModel against a fresh repository, since
    // the count the auto-sync check reacts to has to be set before construction.

    @Test
    fun `syncs automatically on init when the local database is empty`() = runTest {
        val emptyRepository = FakeRestaurantRepository(count = 0)
        val freshSyncManager = FakeDatabaseSyncManager()

        RestaurantListViewModel(repository = emptyRepository, syncManager = freshSyncManager)

        assertEquals(1, freshSyncManager.syncCallCount)
    }

    @Test
    fun `does not sync automatically when the local database already has data`() = runTest {
        val nonEmptyRepository = FakeRestaurantRepository(count = 1)
        val freshSyncManager = FakeDatabaseSyncManager()

        RestaurantListViewModel(repository = nonEmptyRepository, syncManager = freshSyncManager)

        assertEquals(0, freshSyncManager.syncCallCount)
    }
}

/**
 * Records the arguments the ViewModel passes down and replays whatever the test
 * pushes into it. It deliberately does not filter: that is the DAO's job.
 */
private class FakeRestaurantRepository(var count: Int = 0) : RestaurantRepository {

    val restaurants = MutableStateFlow<List<Restaurant>>(emptyList())
    val cuisines = MutableStateFlow<List<String>>(emptyList())

    var lastQuery: String? = null
        private set
    var lastMinRating: Int? = null
        private set
    var lastCuisine: String? = null
        private set
    var lastSort: RestaurantSort? = null
        private set

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort
    ): Flow<List<Restaurant>> {
        lastQuery = query
        lastMinRating = minRating
        lastCuisine = cuisineType
        lastSort = sort
        return restaurants
    }

    override fun observeCuisineTypes(): Flow<List<String>> = cuisines

    override fun observeById(id: Long): Flow<Restaurant?> =
        restaurants.map { list -> list.firstOrNull { it.id == id } }

    override suspend fun count(): Int = count

    override suspend fun replaceAll(restaurants: List<Restaurant>) {
        this.restaurants.value = restaurants
    }
}

/** Never touches the network: records how often sync() was asked for and replays a canned result. */
private class FakeDatabaseSyncManager(
    private val result: DatabaseSyncResult = DatabaseSyncResult.Success(0)
) : DatabaseSyncManager {

    var syncCallCount = 0
        private set

    override suspend fun sync(): DatabaseSyncResult {
        syncCallCount++
        return result
    }
}
