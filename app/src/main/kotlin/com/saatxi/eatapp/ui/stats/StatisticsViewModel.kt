package com.saatxi.eatapp.ui.stats

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.repository.RestaurantRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn

data class StatisticsUiState(
    val totalCount: Int = 0,
    val visitedCount: Int = 0,
    /** Null when nothing has a real rating yet (a want-to-try row's `rating = 0` isn't one). */
    val averageRating: Double? = null,
    /** Highest count first — see `RestaurantDao.observeCuisineCounts`. */
    val cuisineCounts: List<CuisineCount> = emptyList(),
    val priceRangeCounts: List<PriceRangeCount> = emptyList(),
    // Same purpose as RestaurantListUiState.isInitialLoad: true until the
    // repository has emitted for the first time, so the empty state can't be
    // mistaken for "no restaurants yet" before the real counts arrive.
    val isInitialLoad: Boolean = true
) {
    val wantToTryCount: Int get() = totalCount - visitedCount
}

/**
 * Backs the statistics screen (F-64): most-picked cuisines, average rating,
 * price-tier spread, visited vs. want-to-try — all aggregated locally by
 * Room, no network call and no charting library.
 */
class StatisticsViewModel(repository: RestaurantRepository) : ViewModel() {

    val uiState: StateFlow<StatisticsUiState> = combine(
        repository.observeTotalCount(),
        repository.observeVisitedCount(),
        repository.observeAverageRating(),
        repository.observeCuisineCounts(),
        repository.observePriceRangeCounts()
    ) { totalCount, visitedCount, averageRating, cuisineCounts, priceRangeCounts ->
        StatisticsUiState(
            totalCount = totalCount,
            visitedCount = visitedCount,
            averageRating = averageRating,
            cuisineCounts = cuisineCounts,
            priceRangeCounts = priceRangeCounts,
            isInitialLoad = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = StatisticsUiState()
    )
}
