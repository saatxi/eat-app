package com.saatxi.eatapp.ui.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.model.toUiModel
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
    private val restaurantId: Long
) : ViewModel() {

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
