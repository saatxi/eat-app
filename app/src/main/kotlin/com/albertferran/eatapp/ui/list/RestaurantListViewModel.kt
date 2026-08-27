package com.albertferran.eatapp.ui.list

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.albertferran.eatapp.data.local.RestaurantSort
import com.albertferran.eatapp.data.repository.RestaurantRepository
import com.albertferran.eatapp.data.sync.DatabaseSyncManager
import com.albertferran.eatapp.data.sync.DatabaseSyncResult
import com.albertferran.eatapp.data.sync.SyncFailureReason
import com.albertferran.eatapp.ui.model.RestaurantUiModel
import com.albertferran.eatapp.ui.model.toUiModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class RestaurantListUiState(
    val searchQuery: String = "",
    val minRating: Int? = null,
    val cuisineType: String? = null,
    val sort: RestaurantSort = RestaurantSort.NAME,
    val availableCuisines: List<String> = emptyList(),
    val restaurants: List<RestaurantUiModel> = emptyList(),
    // True until the database has emitted for the first time. Without it this
    // initial (empty) state is indistinguishable from a genuinely empty
    // database, and the "No restaurants yet" screen flashes for a frame on
    // every cold start.
    val isInitialLoad: Boolean = true,
    val isSyncing: Boolean = false,
    val pendingSyncMessage: SyncMessage? = null
) {
    val hasActiveFilter: Boolean
        get() = searchQuery.isNotBlank() || minRating != null || cuisineType != null
}

// Carried in the UI state rather than a SharedFlow event, so a message
// survives a config change instead of depending on a collector being
// attached at the exact moment it is emitted. The screen calls
// onSyncMessageShown() once it has displayed it.
sealed interface SyncMessage {
    data class Success(val count: Int) : SyncMessage
    data object UpToDate : SyncMessage
    data class Error(val reason: SyncFailureReason) : SyncMessage
}

private data class Filters(
    val query: String = "",
    val minRating: Int? = null,
    val cuisineType: String? = null,
    // Not a filter in the "narrows the list down" sense — it rides along here
    // because it is the fourth input the repository query is built from.
    val sort: RestaurantSort = RestaurantSort.NAME
)

@OptIn(ExperimentalCoroutinesApi::class, FlowPreview::class)
class RestaurantListViewModel(
    private val repository: RestaurantRepository,
    private val syncManager: DatabaseSyncManager
) : ViewModel() {

    private val filters = MutableStateFlow(Filters())
    private val isSyncing = MutableStateFlow(false)
    private val pendingSyncMessage = MutableStateFlow<SyncMessage?>(null)

    init {
        // A fresh install has an empty local database and no way to reach it other
        // than the manual "Refresh Data" button; this is what lets the first launch
        // fill itself in instead of sitting on the empty state until a tap.
        viewModelScope.launch {
            if (repository.count() == 0) {
                syncNow()
            }
        }
    }

    // The search box updates the visible text on every keystroke (via
    // `filters` below), but only debounces the query actually sent to the
    // repository — an empty query (e.g. clearing the field) skips the
    // debounce so results reappear immediately.
    private val queryFilters: Flow<Filters> = combine(
        filters.map { it.query }.debounce { query -> if (query.isBlank()) 0L else SEARCH_DEBOUNCE_MS },
        filters.map { it.minRating }.distinctUntilChanged(),
        filters.map { it.cuisineType }.distinctUntilChanged(),
        filters.map { it.sort }.distinctUntilChanged(),
        ::Filters
    )

    val uiState: StateFlow<RestaurantListUiState> = combine(
        filters,
        queryFilters.flatMapLatest { repository.observeFiltered(it.query, it.minRating, it.cuisineType, it.sort) },
        repository.observeCuisineTypes(),
        isSyncing,
        pendingSyncMessage
    ) { activeFilters, restaurants, availableCuisines, syncing, syncMessage ->
        RestaurantListUiState(
            searchQuery = activeFilters.query,
            minRating = activeFilters.minRating,
            cuisineType = activeFilters.cuisineType,
            sort = activeFilters.sort,
            availableCuisines = availableCuisines,
            restaurants = restaurants.map { it.toUiModel() },
            // Reaching this block at all means the database has emitted, since
            // combine produces nothing until every source has.
            isInitialLoad = false,
            isSyncing = syncing,
            pendingSyncMessage = syncMessage
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = RestaurantListUiState()
    )

    fun onSearchQueryChange(query: String) {
        filters.update { it.copy(query = query) }
    }

    fun onMinRatingChange(minRating: Int?) {
        filters.update { it.copy(minRating = minRating) }
    }

    fun onCuisineChange(cuisineType: String?) {
        filters.update { it.copy(cuisineType = cuisineType) }
    }

    fun onSortChange(sort: RestaurantSort) {
        filters.update { it.copy(sort = sort) }
    }

    // Deliberately leaves the sort order alone: it is reached from the "no
    // matches" state, where the user wants their restaurants back, not their
    // chosen order undone.
    fun clearFilters() {
        filters.value = Filters(sort = filters.value.sort)
    }

    fun syncNow() {
        if (isSyncing.value) return
        viewModelScope.launch {
            isSyncing.value = true
            val message = when (val result = syncManager.sync()) {
                is DatabaseSyncResult.Success -> SyncMessage.Success(result.importedCount)
                DatabaseSyncResult.UpToDate -> SyncMessage.UpToDate
                is DatabaseSyncResult.Failure -> SyncMessage.Error(result.reason)
            }
            isSyncing.value = false
            pendingSyncMessage.value = message
        }
    }

    /** Called once the screen has displayed the pending message, so it isn't shown again. */
    fun onSyncMessageShown() {
        pendingSyncMessage.value = null
    }

    private companion object {
        const val SEARCH_DEBOUNCE_MS = 250L
    }
}
