package com.albertferran.eatapp.ui.list

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.repository.RestaurantRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update

data class RestaurantListUiState(
    val searchQuery: String = "",
    val minRating: Int? = null,
    val restaurants: List<Restaurant> = emptyList()
)

@OptIn(ExperimentalCoroutinesApi::class)
class RestaurantListViewModel(
    private val repository: RestaurantRepository
) : ViewModel() {

    private val filters = MutableStateFlow("" to null as Pair<String, Int?>)

    val uiState: StateFlow<RestaurantListUiState> = filters
        .flatMapLatest { (query, minRating) ->
            repository.observeFiltered(query, minRating).map { restaurants ->
                RestaurantListUiState(
                    searchQuery = query,
                    minRating = minRating,
                    restaurants = restaurants
                )
            }
        }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = RestaurantListUiState()
        )

    fun onSearchQueryChange(query: String) {
        filters.update { it.copy(first = query) }
    }

    fun onMinRatingChange(minRating: Int?) {
        filters.update { it.copy(second = minRating) }
    }
}
