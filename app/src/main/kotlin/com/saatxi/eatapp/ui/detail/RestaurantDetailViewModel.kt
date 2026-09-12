package com.saatxi.eatapp.ui.detail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.model.toUiModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
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

@HiltViewModel
class RestaurantDetailViewModel @Inject constructor(
    private val repository: RestaurantRepository,
    private val preferencesRepository: UserPreferencesRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val restaurantId: String = checkNotNull(savedStateHandle["restaurantId"])

    val uiState: StateFlow<DetailUiState> = combine(
        repository.observeById(restaurantId),
        preferencesRepository.preferences.map { it.favoriteIds },
        repository.observeTagNames(restaurantId),
        repository.observeVisitsForRestaurant(restaurantId)
    ) { restaurant, favoriteIds, tags, visits ->
        when (restaurant) {
            null -> DetailUiState.NotFound
            else -> DetailUiState.Loaded(
                restaurant.toUiModel(isFavorite = restaurant.id in favoriteIds, tags = tags, latestVisit = visits.firstOrNull())
            )
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = DetailUiState.Loading
    )

    fun onFavoriteToggle() {
        viewModelScope.launch { preferencesRepository.toggleFavorite(restaurantId) }
    }

    /** [onDeleted] is called once the row is gone, so the screen can navigate back. */
    fun onDelete(onDeleted: () -> Unit) {
        viewModelScope.launch {
            repository.delete(restaurantId)
            onDeleted()
        }
    }
}
