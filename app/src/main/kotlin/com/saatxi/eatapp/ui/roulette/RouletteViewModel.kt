package com.saatxi.eatapp.ui.roulette

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
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
import kotlin.random.Random

/** Grouped into one state so a `combine()` adding [visited] doesn't grow past kotlinx.coroutines' typed 5-flow overload. */
private data class RouletteFilters(
    val minRating: Int? = null,
    val favoritesOnly: Boolean = false,
    val visited: Boolean? = null
)

data class RouletteUiState(
    val minRating: Int? = null,
    val favoritesOnly: Boolean = false,
    val visited: Boolean? = null,
    val candidates: List<RestaurantUiModel> = emptyList(),
    val picked: RestaurantUiModel? = null,
    // Bumped on every pick(), so the UI can retrigger its shuffle animation even
    // when chance lands on the same restaurant twice in a row.
    val pickCount: Int = 0,
    val isInitialLoad: Boolean = true
) {
    val isEmpty: Boolean get() = !isInitialLoad && candidates.isEmpty()
}

/**
 * Picks at random among the restaurants passing this screen's own light filters,
 * reusing `repository.observeFiltered(...)` unchanged rather than adding a new
 * query. [random] is injected so a test can seed it and assert a deterministic pick.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RouletteViewModel(
    private val repository: RestaurantRepository,
    private val preferencesRepository: UserPreferencesRepository,
    private val random: Random = Random.Default
) : ViewModel() {

    private val filters = MutableStateFlow(RouletteFilters())
    private val picked = MutableStateFlow<RestaurantUiModel?>(null)
    private val pickCount = MutableStateFlow(0)

    private val candidates: Flow<List<RestaurantUiModel>> = combine(
        filters.flatMapLatest { f ->
            repository.observeFiltered(query = null, minRating = f.minRating, cuisineType = null, visited = f.visited)
        },
        preferencesRepository.preferences.map { it.favoriteIds },
        filters
    ) { restaurants, favoriteIds, f ->
        restaurants
            .filter { !f.favoritesOnly || it.id in favoriteIds }
            .map { it.toUiModel(isFavorite = it.id in favoriteIds) }
    }

    val uiState: StateFlow<RouletteUiState> = combine(
        filters,
        candidates,
        picked,
        pickCount
    ) { f, candidateList, pickedRestaurant, count ->
        RouletteUiState(
            minRating = f.minRating,
            favoritesOnly = f.favoritesOnly,
            visited = f.visited,
            candidates = candidateList,
            // Cleared once the filters move it out of the candidate pool, so the
            // screen falls back to the "pick one" prompt instead of showing a
            // restaurant that no longer matches.
            picked = pickedRestaurant?.takeIf { p -> candidateList.any { it.id == p.id } },
            pickCount = count,
            isInitialLoad = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = RouletteUiState()
    )

    fun onMinRatingChange(rating: Int?) {
        filters.update { it.copy(minRating = rating) }
    }

    fun onFavoritesOnlyChange(favoritesOnly: Boolean) {
        filters.update { it.copy(favoritesOnly = favoritesOnly) }
    }

    fun onVisitedChange(visited: Boolean?) {
        filters.update { it.copy(visited = visited) }
    }

    fun pick() {
        picked.value = uiState.value.candidates.randomOrNull(random)
        pickCount.value++
    }
}
