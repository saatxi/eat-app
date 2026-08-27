package com.albertferran.eatapp.ui.list

import androidx.test.core.app.ApplicationProvider
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.repository.RestaurantRepository
import com.albertferran.eatapp.data.sync.RestaurantDatabaseSyncManager
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
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The ViewModel's job here is wiring: turning three independent filter inputs
 * into one repository query and one UI state. The filtering itself belongs to
 * the DAO and is covered by RestaurantDaoTest.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class RestaurantListViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var repository: FakeRestaurantRepository
    private lateinit var viewModel: RestaurantListViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        repository = FakeRestaurantRepository()
        viewModel = RestaurantListViewModel(
            repository = repository,
            syncManager = RestaurantDatabaseSyncManager(
                ApplicationProvider.getApplicationContext(),
                repository
            )
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

    // --- initial state ------------------------------------------------------

    @Test
    fun `starts empty, with no filter and not syncing`() = runTest {
        observeState()

        val state = viewModel.uiState.value
        assertEquals("", state.searchQuery)
        assertNull(state.minRating)
        assertNull(state.cuisineType)
        assertEquals(emptyList<Restaurant>(), state.restaurants)
        assertFalse(state.isSyncing)
        assertFalse(state.hasActiveFilter)
    }

    // --- filters reach the repository and the state -------------------------

    @Test
    fun `a search query lands in the state and in the query`() = runTest {
        observeState()

        viewModel.onSearchQueryChange("ferran")

        assertEquals("ferran", viewModel.uiState.value.searchQuery)
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

    // --- data flowing the other way ----------------------------------------

    @Test
    fun `restaurants from the repository reach the state`() = runTest {
        observeState()

        repository.restaurants.value = listOf(restaurant(1, "Cal Ferran"), restaurant(2, "Bar Nil"))

        assertEquals(listOf("Cal Ferran", "Bar Nil"), viewModel.uiState.value.restaurants.map { it.name })
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
}

/**
 * Records the arguments the ViewModel passes down and replays whatever the test
 * pushes into it. It deliberately does not filter: that is the DAO's job.
 */
private class FakeRestaurantRepository : RestaurantRepository {

    val restaurants = MutableStateFlow<List<Restaurant>>(emptyList())
    val cuisines = MutableStateFlow<List<String>>(emptyList())

    var lastQuery: String? = null
        private set
    var lastMinRating: Int? = null
        private set
    var lastCuisine: String? = null
        private set

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?
    ): Flow<List<Restaurant>> {
        lastQuery = query
        lastMinRating = minRating
        lastCuisine = cuisineType
        return restaurants
    }

    override fun observeCuisineTypes(): Flow<List<String>> = cuisines

    override fun observeById(id: Long): Flow<Restaurant?> =
        restaurants.map { list -> list.firstOrNull { it.id == id } }

    override suspend fun replaceAll(restaurants: List<Restaurant>) {
        this.restaurants.value = restaurants
    }
}
