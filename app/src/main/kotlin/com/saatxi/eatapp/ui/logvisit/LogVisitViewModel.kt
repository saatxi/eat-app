package com.saatxi.eatapp.ui.logvisit

import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.photo.RestaurantPhotoStorage
import com.saatxi.eatapp.data.repository.RestaurantRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Widest rating scale a visit can hold; see [com.saatxi.eatapp.data.local.Visit]. */
private const val MAX_RATING = 5

data class LogVisitUiState(
    /** Epoch millis; defaults to "now" and is only ever changed through the date picker. */
    val visitDate: Long = System.currentTimeMillis(),
    val rating: Int = 0,
    val notes: String = "",
    /** Already-copied photos for this visit, in the order they'll be saved. */
    val photoPaths: List<String> = emptyList(),
    val isSaving: Boolean = false
)

/**
 * Backs the "log a visit" form (`ui/logvisit/`), opened from the detail
 * screen's FAB for one restaurant — unlike `RestaurantEditViewModel`, this
 * always creates a brand-new [com.saatxi.eatapp.data.local.Visit] rather
 * than editing place-level data, so there is no "existing restaurant" branch
 * to load here.
 */
@HiltViewModel
class LogVisitViewModel @Inject constructor(
    private val repository: RestaurantRepository,
    private val photoStorage: RestaurantPhotoStorage,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val restaurantId: String = checkNotNull(savedStateHandle["restaurantId"])

    private val _uiState = MutableStateFlow(LogVisitUiState())
    val uiState: StateFlow<LogVisitUiState> = _uiState.asStateFlow()

    fun onDateChange(visitDate: Long) {
        _uiState.update { it.copy(visitDate = visitDate) }
    }

    fun onRatingChange(rating: Int) {
        _uiState.update { it.copy(rating = rating.coerceIn(0, MAX_RATING)) }
    }

    fun onNotesChange(notes: String) {
        _uiState.update { it.copy(notes = notes) }
    }

    /**
     * Copies [uri] into permanent storage right away, unlike the edit form's
     * single pending photo — a visit can carry several, so each pick is
     * resolved to its own stored path as soon as it's made rather than all
     * being deferred to save time; a copy that fails is silently dropped,
     * the same fallback behaviour `RestaurantEditViewModel` uses for its one photo.
     */
    fun onPhotoPicked(uri: Uri) {
        viewModelScope.launch {
            val path = photoStorage.copy(uri) ?: return@launch
            _uiState.update { it.copy(photoPaths = it.photoPaths + path) }
        }
    }

    fun onRemovePhoto(path: String) {
        _uiState.update { it.copy(photoPaths = it.photoPaths.filterNot { existing -> existing == path }) }
    }

    fun onSave(onSaved: () -> Unit) {
        val state = _uiState.value
        if (state.isSaving) return
        _uiState.update { it.copy(isSaving = true) }
        viewModelScope.launch {
            repository.addVisit(
                restaurantId = restaurantId,
                visitDate = state.visitDate,
                rating = state.rating,
                notes = state.notes.trim().takeIf { it.isNotBlank() },
                photoPaths = state.photoPaths
            )
            onSaved()
        }
    }
}

