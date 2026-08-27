package com.albertferran.eatapp.ui.list

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.repository.RestaurantRepository
import com.albertferran.eatapp.data.sync.DatabaseSyncResult
import com.albertferran.eatapp.data.sync.RestaurantDatabaseSyncManager
import com.albertferran.eatapp.data.sync.SyncFailureReason
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
    val availableCuisines: List<String> = emptyList(),
    val restaurants: List<Restaurant> = emptyList(),
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
    data class Error(val reason: SyncFailureReason) : SyncMessage
}

private data class Filters(
    val query: String = "",
    val minRating: Int? = null,
    val cuisineType: String? = null
)

@OptIn(ExperimentalCoroutinesApi::class, FlowPreview::class)
class RestaurantListViewModel(
    private val repository: RestaurantRepository,
    private val syncManager: RestaurantDatabaseSyncManager
) : ViewModel() {

    private val filters = MutableStateFlow(Filters())
    private val isSyncing = MutableStateFlow(false)
    private val pendingSyncMessage = MutableStateFlow<SyncMessage?>(null)

    // The search box updates the visible text on every keystroke (via
    // `filters` below), but only debounces the query actually sent to the
    // repository — an empty query (e.g. clearing the field) skips the
    // debounce so results reappear immediately.
    private val queryFilters: Flow<Filters> = combine(
        filters.map { it.query }.debounce { query -> if (query.isBlank()) 0L else SEARCH_DEBOUNCE_MS },
        filters.map { it.minRating }.distinctUntilChanged(),
        filters.map { it.cuisineType }.distinctUntilChanged(),
        ::Filters
    )

    val uiState: StateFlow<RestaurantListUiState> = combine(
        filters,
        queryFilters.flatMapLatest { repository.observeFiltered(it.query, it.minRating, it.cuisineType) },
        repository.observeCuisineTypes(),
        isSyncing,
        pendingSyncMessage
    ) { activeFilters, restaurants, availableCuisines, syncing, syncMessage ->
        RestaurantListUiState(
            searchQuery = activeFilters.query,
            minRating = activeFilters.minRating,
            cuisineType = activeFilters.cuisineType,
            availableCuisines = availableCuisines,
            restaurants = restaurants,
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

    fun clearFilters() {
        filters.value = Filters()
    }

    fun syncNow() {
        if (isSyncing.value) return
        viewModelScope.launch {
            isSyncing.value = true
            val message = when (val result = syncManager.sync()) {
                is DatabaseSyncResult.Success -> SyncMessage.Success(result.importedCount)
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
