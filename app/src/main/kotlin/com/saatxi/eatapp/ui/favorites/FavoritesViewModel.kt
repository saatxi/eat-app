package com.saatxi.eatapp.ui.favorites

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

data class FavoritesUiState(
    val restaurants: List<RestaurantUiModel> = emptyList(),
    // Same purpose as RestaurantListUiState.isInitialLoad: true until the
    // repository has emitted for the first time, so the empty state doesn't
    // flash before the real data arrives.
    val isInitialLoad: Boolean = true
)

/**
 * No new DAO query: the unfiltered stream is reused and narrowed down to the
 * favourited ids here, the same way Roulette (Phase 6) reuses it narrowed down
 * by rating and cuisine instead.
 */
class FavoritesViewModel(
    repository: RestaurantRepository,
    private val preferencesRepository: UserPreferencesRepository
) : ViewModel() {

    val uiState: StateFlow<FavoritesUiState> = combine(
        repository.observeFiltered(query = null, minRating = null, cuisineType = null),
        preferencesRepository.preferences.map { it.favoriteIds }
    ) { restaurants, favoriteIds ->
        FavoritesUiState(
            restaurants = restaurants
                .filter { it.id in favoriteIds }
                .map { it.toUiModel(isFavorite = true) },
            isInitialLoad = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = FavoritesUiState()
    )

    fun onFavoriteToggle(restaurantId: Long) {
        viewModelScope.launch { preferencesRepository.toggleFavorite(restaurantId) }
    }
}
