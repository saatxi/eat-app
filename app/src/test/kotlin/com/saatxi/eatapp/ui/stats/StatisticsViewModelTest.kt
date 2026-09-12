package com.saatxi.eatapp.ui.stats

import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.TagCount
import com.saatxi.eatapp.data.repository.FakeRestaurantRepository
import java.util.Calendar
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

    @Test
    fun `tagCounts carries the repository's ranking through unchanged`() = runTest {
        observeState()
        repository.tagCounts.value = listOf(TagCount("Terraza", 6), TagCount("Brunch", 2))

        assertEquals(listOf(TagCount("Terraza", 6), TagCount("Brunch", 2)), viewModel.uiState.value.tagCounts)
    }

    @Test
    fun `monthlyVisitCounts buckets raw visit dates into the trailing 6 months`() = runTest {
        observeState()
        val now = Calendar.getInstance()
        val thisMonth = now.timeInMillis
        val lastMonth = (now.clone() as Calendar).apply { add(Calendar.MONTH, -1) }.timeInMillis
        repository.allVisitDates.value = listOf(thisMonth, thisMonth, lastMonth)

        val counts = viewModel.uiState.value.monthlyVisitCounts

        assertEquals(6, counts.size)
        assertEquals(2, counts.last().count)
        assertEquals(1, counts[counts.size - 2].count)
    }
}

class BucketVisitsByMonthTest {

    @Test
    fun `zero-fills months with no visits and keeps the trailing 6 months oldest first`() {
        val now = Calendar.getInstance().apply {
            set(Calendar.YEAR, 2026)
            set(Calendar.MONTH, Calendar.SEPTEMBER)
            set(Calendar.DAY_OF_MONTH, 15)
        }.timeInMillis

        val counts = bucketVisitsByMonth(emptyList(), now)

        assertEquals(6, counts.size)
        assertEquals("2026-04", counts.first().monthKey)
        assertEquals("2026-09", counts.last().monthKey)
        assertTrue(counts.all { it.count == 0 })
    }

    @Test
    fun `counts a visit into its own calendar month`() {
        val now = Calendar.getInstance().apply {
            set(Calendar.YEAR, 2026)
            set(Calendar.MONTH, Calendar.SEPTEMBER)
            set(Calendar.DAY_OF_MONTH, 15)
        }.timeInMillis
        val visitInAugust = Calendar.getInstance().apply {
            set(Calendar.YEAR, 2026)
            set(Calendar.MONTH, Calendar.AUGUST)
            set(Calendar.DAY_OF_MONTH, 3)
        }.timeInMillis

        val counts = bucketVisitsByMonth(listOf(visitInAugust, visitInAugust), now)

        assertEquals(2, counts.first { it.monthKey == "2026-08" }.count)
    }
}
