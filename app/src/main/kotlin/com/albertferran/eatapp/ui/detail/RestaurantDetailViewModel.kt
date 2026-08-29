package com.albertferran.eatapp.ui.detail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.albertferran.eatapp.data.prefs.UserPreferencesRepository
import com.albertferran.eatapp.data.repository.RestaurantRepository
import com.albertferran.eatapp.ui.model.RestaurantUiModel
import com.albertferran.eatapp.ui.model.toUiModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

sealed interface DetailUiState {
    data object Loading : DetailUiState
    data class Loaded(val restaurant: RestaurantUiModel) : DetailUiState
    data object NotFound : DetailUiState
}

class RestaurantDetailViewModel(
    repository: RestaurantRepository,
    private val preferencesRepository: UserPreferencesRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val restaurantId: Long = checkNotNull(savedStateHandle["restaurantId"])

    val uiState: StateFlow<DetailUiState> = combine(
        repository.observeById(restaurantId),
        preferencesRepository.preferences.map { it.favoriteIds }
    ) { restaurant, favoriteIds ->
        when (restaurant) {
            null -> DetailUiState.NotFound
            else -> DetailUiState.Loaded(restaurant.toUiModel(isFavorite = restaurant.id in favoriteIds))
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = DetailUiState.Loading
    )

    fun onFavoriteToggle() {
        viewModelScope.launch { preferencesRepository.toggleFavorite(restaurantId) }
    }
}
