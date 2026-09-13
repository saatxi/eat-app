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
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
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
    val visited: Boolean? = null,
    val sort: RestaurantSort = RestaurantSort.NAME,
    val city: String? = null,
    val region: String? = null,
    val country: String? = null,
    val priceRange: Int? = null,
    val availableCuisines: List<String> = emptyList(),
    val availableCities: List<String> = emptyList(),
    val availableRegions: List<String> = emptyList(),
    val availableCountries: List<String> = emptyList(),
    val restaurants: List<RestaurantUiModel> = emptyList(),
    // True until the database has emitted for the first time. Without it this
    // initial (empty) state is indistinguishable from a genuinely empty
    // database, and the "No restaurants yet" screen flashes for a frame on
    // every cold start.
    val isInitialLoad: Boolean = true
) {
    val hasActiveFilter: Boolean
        get() = searchQuery.isNotBlank() || minRating != null || cuisineType != null || visited != null ||
            city != null || region != null || country != null || priceRange != null
}

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class RestaurantListViewModel @Inject constructor(
    private val repository: RestaurantRepository,
    private val preferencesRepository: UserPreferencesRepository
) : ViewModel() {

    private val filters = MutableStateFlow(RestaurantFilters())
    private val queryFilters: Flow<RestaurantFilters> = filters.debounced()

    // Combined separately from the outer state so the outer combine() stays within
    // kotlinx.coroutines' 5-flow overload instead of dropping to the untyped
    // vararg one.
    private val restaurantsWithFavorites: Flow<List<RestaurantUiModel>> = combine(
        queryFilters.flatMapLatest {
            repository.observeFiltered(it.query, it.minRating, it.cuisineType, it.sort, it.visited, it.city, it.region, it.country, it.priceRange)
        },
        preferencesRepository.preferences.map { it.favoriteIds },
        repository.observeTagsByRestaurantId(),
        repository.observeLatestVisitByRestaurantId()
    ) { restaurants, favoriteIds, tagsByRestaurantId, latestVisitByRestaurantId ->
        restaurants.map {
            it.toUiModel(
                isFavorite = it.id in favoriteIds,
                tags = tagsByRestaurantId[it.id].orEmpty(),
                latestVisit = latestVisitByRestaurantId[it.id]
            )
        }
    }

    private val availableFilterValues: Flow<AvailableFilterValues> = repository.observeAvailableFilterValues()

    val uiState: StateFlow<RestaurantListUiState> = combine(
        filters,
        restaurantsWithFavorites,
        availableFilterValues
    ) { activeFilters, restaurants, available ->
        RestaurantListUiState(
            searchQuery = activeFilters.query,
            minRating = activeFilters.minRating,
            cuisineType = activeFilters.cuisineType,
            visited = activeFilters.visited,
            sort = activeFilters.sort,
            city = activeFilters.city,
            region = activeFilters.region,
            country = activeFilters.country,
            priceRange = activeFilters.priceRange,
            availableCuisines = available.cuisines,
            availableCities = available.cities,
            availableRegions = available.regions,
            availableCountries = available.countries,
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

    fun onVisitedChange(visited: Boolean?) {
        filters.update { it.copy(visited = visited) }
    }

    fun onSortChange(sort: RestaurantSort) {
        filters.update { it.copy(sort = sort) }
    }

    fun onCityChange(city: String?) {
        filters.update { it.copy(city = city) }
    }

    fun onRegionChange(region: String?) {
        filters.update { it.copy(region = region) }
    }

    fun onCountryChange(country: String?) {
        filters.update { it.copy(country = country) }
    }

    fun onPriceRangeChange(priceRange: Int?) {
        filters.update { it.copy(priceRange = priceRange) }
    }

    fun onFavoriteToggle(restaurantId: String) {
        viewModelScope.launch { preferencesRepository.toggleFavorite(restaurantId) }
    }

    /** F-65's swipe-to-delete — the caller has already shown a confirmation before calling this. */
    fun onDeleteRestaurant(restaurantId: String) {
        viewModelScope.launch { repository.delete(restaurantId) }
    }

    /**
     * Shares every restaurant, ignoring the active filters — "share all"
     * means all, not just what's currently visible.
     */
    fun onShareAll(context: Context) {
        viewModelScope.launch {
            val all = repository.observeFiltered(query = null, minRating = null, cuisineType = null).first()
            val tagsByRestaurantId = repository.observeTagsByRestaurantId().first()
            context.shareRestaurants(
                all.map { restaurant ->
                    val visits = repository.observeVisitsForRestaurant(restaurant.id).first()
                    restaurant.toExport(tagsByRestaurantId[restaurant.id].orEmpty(), visits)
                }
            )
        }
    }

    // Deliberately leaves the sort order alone: it is reached from the "no
    // matches" state, where the user wants their restaurants back, not their
    // chosen order undone.
    fun clearFilters() {
        filters.value = RestaurantFilters(sort = filters.value.sort)
    }
}
