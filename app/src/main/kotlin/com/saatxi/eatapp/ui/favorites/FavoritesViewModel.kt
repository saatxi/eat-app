package com.saatxi.eatapp.ui.favorites

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.ui.list.RestaurantFilters
import com.saatxi.eatapp.ui.list.debounced
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.model.toUiModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Same shape as `RestaurantListUiState` (F-60): favourites is the same kind
 * of list as the main one, so it gets the same search/sort/filter state
 * rather than a cut-down one.
 */
data class FavoritesUiState(
    val searchQuery: String = "",
    val minRating: Int? = null,
    val cuisineType: String? = null,
    val visited: Boolean? = null,
    val sort: RestaurantSort = RestaurantSort.NAME,
    val availableCuisines: List<String> = emptyList(),
    val restaurants: List<RestaurantUiModel> = emptyList(),
    // Same purpose as RestaurantListUiState.isInitialLoad: true until the
    // repository has emitted for the first time, so the empty state doesn't
    // flash before the real data arrives.
    val isInitialLoad: Boolean = true
) {
    val hasActiveFilter: Boolean
        get() = searchQuery.isNotBlank() || minRating != null || cuisineType != null || visited != null
}

/**
 * No new DAO query: the same `observeFiltered` the list screen queries is
 * reused here too — favouriting doesn't need its own search/sort/filter
 * implementation, just the same query narrowed down to favourited ids
 * afterward (F-60), the same way Roulette narrows it down by rating and
 * cuisine instead.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class FavoritesViewModel(
    private val repository: RestaurantRepository,
    private val preferencesRepository: UserPreferencesRepository
) : ViewModel() {

    private val filters = MutableStateFlow(RestaurantFilters())
    private val queryFilters: Flow<RestaurantFilters> = filters.debounced()

    // Combined separately from the outer state for the same reason
    // RestaurantListViewModel's own restaurantsWithFavorites is: it keeps the
    // outer combine() within kotlinx.coroutines' typed 5-flow overload.
    private val favoriteRestaurants: Flow<List<RestaurantUiModel>> = combine(
        queryFilters.flatMapLatest {
            repository.observeFiltered(it.query, it.minRating, it.cuisineType, it.sort, it.visited)
        },
        preferencesRepository.preferences.map { it.favoriteIds },
        repository.observeTagsByRestaurantId()
    ) { restaurants, favoriteIds, tagsByRestaurantId ->
        restaurants
            .filter { it.id in favoriteIds }
            .map { it.toUiModel(isFavorite = true, tags = tagsByRestaurantId[it.id].orEmpty()) }
    }

    val uiState: StateFlow<FavoritesUiState> = combine(
        filters,
        favoriteRestaurants,
        repository.observeCuisineTypes()
    ) { activeFilters, restaurants, availableCuisines ->
        FavoritesUiState(
            searchQuery = activeFilters.query,
            minRating = activeFilters.minRating,
            cuisineType = activeFilters.cuisineType,
            visited = activeFilters.visited,
            sort = activeFilters.sort,
            availableCuisines = availableCuisines,
            restaurants = restaurants,
            isInitialLoad = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = FavoritesUiState()
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

    fun onVisitedChange(visited: Boolean?) {
        filters.update { it.copy(visited = visited) }
    }

    fun onSortChange(sort: RestaurantSort) {
        filters.update { it.copy(sort = sort) }
    }

    fun onFavoriteToggle(restaurantId: Long) {
        viewModelScope.launch { preferencesRepository.toggleFavorite(restaurantId) }
    }

    /** F-65's swipe-to-delete — the caller has already shown a confirmation before calling this. */
    fun onDeleteRestaurant(restaurantId: Long) {
        viewModelScope.launch { repository.delete(restaurantId) }
    }

    // Deliberately leaves the sort order alone — see RestaurantListViewModel's
    // own clearFilters for why.
    fun clearFilters() {
        filters.value = RestaurantFilters(sort = filters.value.sort)
    }
}
