package com.saatxi.eatapp.ui.stats

import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.repository.RestaurantRepository
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

@OptIn(ExperimentalCoroutinesApi::class)
class StatisticsViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var repository: FakeRestaurantRepository
    private lateinit var viewModel: StatisticsViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        repository = FakeRestaurantRepository()
        viewModel = StatisticsViewModel(repository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    /** stateIn's upstream (the five combined flows) only runs once there's a subscriber. */
    private fun TestScope.observeState() {
        backgroundScope.launch(dispatcher) { viewModel.uiState.collect {} }
    }

    @Test
    fun `starts as an initial load with nothing to show`() = runTest {
        val state = viewModel.uiState.value

        assertTrue(state.isInitialLoad)
        assertEquals(0, state.totalCount)
        assertNull(state.averageRating)
    }

    @Test
    fun `once the counts arrive, isInitialLoad clears and the counts carry through`() = runTest {
        observeState()
        repository.totalCount.value = 10
        repository.visitedCount.value = 6
        repository.averageRating.value = 4.2
        repository.cuisineCounts.value = listOf(CuisineCount("japanese", 5), CuisineCount("seafood", 5))
        repository.priceRangeCounts.value = listOf(PriceRangeCount(1, 4), PriceRangeCount(2, 6))

        val state = viewModel.uiState.value
        assertFalse(state.isInitialLoad)
        assertEquals(10, state.totalCount)
        assertEquals(6, state.visitedCount)
        assertEquals(4.2, state.averageRating)
        assertEquals(listOf(CuisineCount("japanese", 5), CuisineCount("seafood", 5)), state.cuisineCounts)
        assertEquals(listOf(PriceRangeCount(1, 4), PriceRangeCount(2, 6)), state.priceRangeCounts)
    }

    @Test
    fun `wantToTryCount is the total minus the visited count`() = runTest {
        observeState()
        repository.totalCount.value = 10
        repository.visitedCount.value = 6

        assertEquals(4, viewModel.uiState.value.wantToTryCount)
    }

    @Test
    fun `a null average rating means nothing is rated yet, not zero`() = runTest {
        observeState()
        repository.totalCount.value = 3
        repository.averageRating.value = null

        assertNull(viewModel.uiState.value.averageRating)
    }
}

private class FakeRestaurantRepository : RestaurantRepository {

    val totalCount = MutableStateFlow(0)
    val visitedCount = MutableStateFlow(0)
    val averageRating = MutableStateFlow<Double?>(null)
    val cuisineCounts = MutableStateFlow<List<CuisineCount>>(emptyList())
    val priceRangeCounts = MutableStateFlow<List<PriceRangeCount>>(emptyList())

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort,
        visited: Boolean?
    ): Flow<List<Restaurant>> =
        throw NotImplementedError("Not used by StatisticsViewModel")

    override fun observeCuisineTypes(): Flow<List<String>> =
        throw NotImplementedError("Not used by StatisticsViewModel")

    override fun observeById(id: Long): Flow<Restaurant?> =
        throw NotImplementedError("Not used by StatisticsViewModel")

    override suspend fun insert(restaurant: Restaurant, tags: List<String>): Long =
        throw NotImplementedError("Not used by StatisticsViewModel")

    override suspend fun update(restaurant: Restaurant, tags: List<String>) =
        throw NotImplementedError("Not used by StatisticsViewModel")

    override suspend fun delete(id: Long) =
        throw NotImplementedError("Not used by StatisticsViewModel")

    override suspend fun deleteAll() =
        throw NotImplementedError("Not used by StatisticsViewModel")

    override fun observeAllTagNames(): Flow<List<String>> =
        throw NotImplementedError("Not used by StatisticsViewModel")

    override fun observeTagNames(restaurantId: Long): Flow<List<String>> =
        throw NotImplementedError("Not used by StatisticsViewModel")

    override fun observeTagsByRestaurantId(): Flow<Map<Long, List<String>>> =
        throw NotImplementedError("Not used by StatisticsViewModel")

    override fun observeTotalCount(): Flow<Int> = totalCount
    override fun observeVisitedCount(): Flow<Int> = visitedCount
    override fun observeAverageRating(): Flow<Double?> = averageRating
    override fun observeCuisineCounts(): Flow<List<CuisineCount>> = cuisineCounts
    override fun observePriceRangeCounts(): Flow<List<PriceRangeCount>> = priceRangeCounts

    override suspend fun getRandomWantToTry(): Restaurant? =
        throw NotImplementedError("Not used by StatisticsViewModel")
}
