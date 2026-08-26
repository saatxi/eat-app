package com.albertferran.eatapp.ui.list

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.repository.RestaurantRepository
import com.albertferran.eatapp.data.sync.DatabaseSyncResult
import com.albertferran.eatapp.data.sync.RestaurantDatabaseSyncManager
import com.albertferran.eatapp.data.sync.SyncFailureReason
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class RestaurantListUiState(
    val searchQuery: String = "",
    val minRating: Int? = null,
    val cuisineType: String? = null,
    val availableCuisines: List<String> = emptyList(),
    val restaurants: List<Restaurant> = emptyList(),
    val isSyncing: Boolean = false
) {
    val hasActiveFilter: Boolean
        get() = searchQuery.isNotBlank() || minRating != null || cuisineType != null
}

sealed interface SyncEvent {
    data class Success(val count: Int) : SyncEvent
    data class Error(val reason: SyncFailureReason) : SyncEvent
}

private data class Filters(
    val query: String = "",
    val minRating: Int? = null,
    val cuisineType: String? = null
)

@OptIn(ExperimentalCoroutinesApi::class)
class RestaurantListViewModel(
    private val repository: RestaurantRepository,
    private val syncManager: RestaurantDatabaseSyncManager
) : ViewModel() {

    private val filters = MutableStateFlow(Filters())
    private val isSyncing = MutableStateFlow(false)

    private val _syncEvents = MutableSharedFlow<SyncEvent>()
    val syncEvents: SharedFlow<SyncEvent> = _syncEvents.asSharedFlow()

    val uiState: StateFlow<RestaurantListUiState> = combine(
        filters,
        filters.flatMapLatest { repository.observeFiltered(it.query, it.minRating, it.cuisineType) },
        repository.observeCuisineTypes(),
        isSyncing
    ) { activeFilters, restaurants, availableCuisines, syncing ->
        RestaurantListUiState(
            searchQuery = activeFilters.query,
            minRating = activeFilters.minRating,
            cuisineType = activeFilters.cuisineType,
            availableCuisines = availableCuisines,
            restaurants = restaurants,
            isSyncing = syncing
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
            val event = when (val result = syncManager.sync()) {
                is DatabaseSyncResult.Success -> SyncEvent.Success(result.importedCount)
                is DatabaseSyncResult.Failure -> SyncEvent.Error(result.reason)
            }
            isSyncing.value = false
            _syncEvents.emit(event)
        }
    }
}
