package com.albertferran.eatapp.ui.detail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.repository.RestaurantRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

sealed interface DetailUiState {
    data object Loading : DetailUiState
    data class Loaded(val restaurant: Restaurant) : DetailUiState
    data object NotFound : DetailUiState
}

class RestaurantDetailViewModel(
    repository: RestaurantRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val restaurantId: Long = checkNotNull(savedStateHandle["restaurantId"])

    val uiState: StateFlow<DetailUiState> = repository.observeById(restaurantId)
        .map { restaurant ->
            when (restaurant) {
                null -> DetailUiState.NotFound
                else -> DetailUiState.Loaded(restaurant)
            }
        }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = DetailUiState.Loading
        )
}
