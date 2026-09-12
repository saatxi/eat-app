package com.saatxi.eatapp.ui.stats

import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.PriceRangeCount
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
