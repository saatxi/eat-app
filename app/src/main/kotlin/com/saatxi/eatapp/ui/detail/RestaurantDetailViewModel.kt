package com.saatxi.eatapp.ui.detail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.local.Photo
import com.saatxi.eatapp.data.local.Visit
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.model.toUiModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** One visit card in the detail screen's timeline — see [RestaurantDetailViewModel.uiState]. */
data class VisitUiModel(
    val id: String,
    /** Epoch millis; formatted at draw time so the ViewModel stays Context-free. */
    val visitDate: Long,
    val rating: Int,
    val notes: String?,
    /** 0-6, 0 meaning "not set" — see [com.saatxi.eatapp.data.local.Visit.priceRange]. */
    val priceRange: Int,
    val photoPaths: List<String>
)

/** One point of a restaurant's own rating-over-time trend — see [DetailUiState.Loaded.ratingTrend]. */
data class RatingPoint(val visitDate: Long, val rating: Int)

sealed interface DetailUiState {
    data object Loading : DetailUiState
    data class Loaded(
        val restaurant: RestaurantUiModel,
        val visits: List<VisitUiModel>,
        /**
         * The restaurant's own visits, oldest first, for the small rating-trend
         * chart above the timeline (F-73's Statistics enrichment) — empty
         * unless there are at least two visits, since a trend needs two points
         * and the screen skips the chart entirely below that.
         */
        val ratingTrend: List<RatingPoint> = emptyList()
    ) : DetailUiState
    data object NotFound : DetailUiState
}

/** Below this many visits, a trend line has nothing to show a slope with. */
private const val MIN_VISITS_FOR_TREND = 2

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class RestaurantDetailViewModel @Inject constructor(
    private val repository: RestaurantRepository,
    private val preferencesRepository: UserPreferencesRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val restaurantId: String = checkNotNull(savedStateHandle["restaurantId"])

    /** Every visit's photos, keyed by visit id — joined in below rather than N separate flows per card. */
    private fun visitPhotos(visits: List<Visit>): Flow<Map<String, List<Photo>>> =
        if (visits.isEmpty()) {
            flowOf(emptyMap())
        } else {
            combine(visits.map { visit -> repository.observePhotosForVisit(visit.id).map { visit.id to it } }) { pairs ->
                pairs.toMap()
            }
        }

    val uiState: StateFlow<DetailUiState> = combine(
        repository.observeById(restaurantId),
        preferencesRepository.preferences.map { it.favoriteIds },
        repository.observeTagNames(restaurantId),
        repository.observeVisitsForRestaurant(restaurantId).flatMapLatest { visits ->
            visitPhotos(visits).map { photosByVisitId -> visits to photosByVisitId }
        }
    ) { restaurant, favoriteIds, tags, (visits, photosByVisitId) ->
        when (restaurant) {
            null -> DetailUiState.NotFound
            else -> DetailUiState.Loaded(
                restaurant = restaurant.toUiModel(isFavorite = restaurant.id in favoriteIds, tags = tags, latestVisit = visits.firstOrNull()),
                visits = visits.map { visit ->
                    VisitUiModel(
                        id = visit.id,
                        visitDate = visit.visitDate,
                        rating = visit.rating,
                        notes = visit.notes?.takeIf { it.isNotBlank() },
                        priceRange = visit.priceRange,
                        photoPaths = photosByVisitId[visit.id].orEmpty().map { it.path }
                    )
                },
                ratingTrend = if (visits.size >= MIN_VISITS_FOR_TREND) {
                    // visits comes newest-first; a trend line reads left-to-right chronologically.
                    visits.sortedBy { it.visitDate }.map { RatingPoint(it.visitDate, it.rating) }
                } else {
                    emptyList()
                }
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
