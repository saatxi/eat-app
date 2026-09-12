package com.saatxi.eatapp.ui.stats

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.TagCount
import com.saatxi.eatapp.data.repository.RestaurantRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import java.util.Calendar
import javax.inject.Inject
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn

/** How many trailing months the "visits per month" chart shows. */
private const val VISIT_TREND_MONTHS = 6

/** One bar of the global "visits per month" chart — [monthKey] is `"YYYY-MM"`, sortable as a plain string. */
data class MonthlyVisitCount(val monthKey: String, val count: Int)

data class StatisticsUiState(
    val totalCount: Int = 0,
    val visitedCount: Int = 0,
    /** Null when nothing has a real rating yet (a want-to-try row's `rating = 0` isn't one). */
    val averageRating: Double? = null,
    /** Highest count first — see `RestaurantDao.observeCuisineCounts`. */
    val cuisineCounts: List<CuisineCount> = emptyList(),
    val priceRangeCounts: List<PriceRangeCount> = emptyList(),
    /** Last [VISIT_TREND_MONTHS] months, oldest first, zero-filled for months with no visits. */
    val monthlyVisitCounts: List<MonthlyVisitCount> = emptyList(),
    /** Most-used tags across every restaurant, highest count first — see `TagDao.observeTagCounts`. */
    val tagCounts: List<TagCount> = emptyList(),
    // Same purpose as RestaurantListUiState.isInitialLoad: true until the
    // repository has emitted for the first time, so the empty state can't be
    // mistaken for "no restaurants yet" before the real counts arrive.
    val isInitialLoad: Boolean = true
) {
    val wantToTryCount: Int get() = totalCount - visitedCount
}

/**
 * Backs the statistics screen (F-64, enriched further for the "mercado
 * fresco" revamp): most-picked cuisines, average rating, price-tier spread,
 * visited vs. want-to-try, a visits-per-month trend and a top-tags ranking —
 * all aggregated locally by Room, no network call and no charting library
 * (charts are Canvas-drawn in `StatisticsScreen`). The visits-per-month and
 * tag rankings are both genuinely *global* metrics (unlike a single
 * restaurant's rating trend, which lives on the Detail screen instead — see
 * `RestaurantDetailViewModel.ratingTrend`), so they belong here rather than
 * being crammed into a per-restaurant view.
 */
@HiltViewModel
class StatisticsViewModel @Inject constructor(repository: RestaurantRepository) : ViewModel() {

    val uiState: StateFlow<StatisticsUiState> = combine(
        repository.observeTotalCount(),
        repository.observeVisitedCount(),
        repository.observeAverageRating(),
        repository.observeCuisineCounts(),
        repository.observePriceRangeCounts(),
        repository.observeAllVisitDates(),
        repository.observeTagCounts()
    ) { values ->
        @Suppress("UNCHECKED_CAST")
        StatisticsUiState(
            totalCount = values[0] as Int,
            visitedCount = values[1] as Int,
            averageRating = values[2] as Double?,
            cuisineCounts = values[3] as List<CuisineCount>,
            priceRangeCounts = values[4] as List<PriceRangeCount>,
            monthlyVisitCounts = bucketVisitsByMonth(values[5] as List<Long>),
            tagCounts = values[6] as List<TagCount>,
            isInitialLoad = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = StatisticsUiState()
    )
}

/**
 * Buckets [visitDates] (epoch millis) into the trailing [VISIT_TREND_MONTHS]
 * calendar months ending with the current one, oldest first, zero-filled for
 * a month with no visits — done in Kotlin rather than SQL (see `VisitDao`)
 * since month-of-epoch-millis isn't a single portable SQLite expression.
 */
internal fun bucketVisitsByMonth(visitDates: List<Long>, now: Long = System.currentTimeMillis()): List<MonthlyVisitCount> {
    fun monthKey(millis: Long): String {
        val calendar = Calendar.getInstance().apply { timeInMillis = millis }
        return "%04d-%02d".format(calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH) + 1)
    }

    val monthKeys = (VISIT_TREND_MONTHS - 1 downTo 0).map { monthsAgo ->
        val calendar = Calendar.getInstance().apply {
            timeInMillis = now
            add(Calendar.MONTH, -monthsAgo)
        }
        monthKey(calendar.timeInMillis)
    }
    val countsByMonth = visitDates.groupingBy(::monthKey).eachCount()
    return monthKeys.map { key -> MonthlyVisitCount(key, countsByMonth[key] ?: 0) }
}
