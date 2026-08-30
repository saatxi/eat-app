package com.saatxi.eatapp.ui.list

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.data.share.toExport
import com.saatxi.eatapp.ui.common.shareRestaurants
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.model.toUiModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
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
    val isInitialLoad: Boolean = true
) {
    val hasActiveFilter: Boolean
        get() = searchQuery.isNotBlank() || minRating != null || cuisineType != null
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
    private val preferencesRepository: UserPreferencesRepository
) : ViewModel() {

    private val filters = MutableStateFlow(Filters())

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

    // Combined separately from the outer state so the outer combine() stays within
    // kotlinx.coroutines' 5-flow overload instead of dropping to the untyped
    // vararg one.
    private val restaurantsWithFavorites: Flow<List<RestaurantUiModel>> = combine(
        queryFilters.flatMapLatest { repository.observeFiltered(it.query, it.minRating, it.cuisineType, it.sort) },
        preferencesRepository.preferences.map { it.favoriteIds }
    ) { restaurants, favoriteIds ->
        restaurants.map { it.toUiModel(isFavorite = it.id in favoriteIds) }
    }

    val uiState: StateFlow<RestaurantListUiState> = combine(
        filters,
        restaurantsWithFavorites,
        repository.observeCuisineTypes()
    ) { activeFilters, restaurants, availableCuisines ->
        RestaurantListUiState(
            searchQuery = activeFilters.query,
            minRating = activeFilters.minRating,
            cuisineType = activeFilters.cuisineType,
            sort = activeFilters.sort,
            availableCuisines = availableCuisines,
            restaurants = restaurants,
            // Reaching this block at all means the database has emitted, since
            // combine produces nothing until every source has.
            isInitialLoad = false
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

    fun onFavoriteToggle(restaurantId: Long) {
        viewModelScope.launch { preferencesRepository.toggleFavorite(restaurantId) }
    }

    /**
     * Shares every restaurant, ignoring the active filters — "share all"
     * means all, not just what's currently visible.
     */
    fun onShareAll(context: Context) {
        viewModelScope.launch {
            val all = repository.observeFiltered(query = null, minRating = null, cuisineType = null).first()
            context.shareRestaurants(all.map { it.toExport() })
        }
    }

    // Deliberately leaves the sort order alone: it is reached from the "no
    // matches" state, where the user wants their restaurants back, not their
    // chosen order undone.
    fun clearFilters() {
        filters.value = Filters(sort = filters.value.sort)
    }

    private companion object {
        const val SEARCH_DEBOUNCE_MS = 250L
    }
}
