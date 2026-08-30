package com.saatxi.eatapp.ui.importing

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.data.share.ContentReadResult
import com.saatxi.eatapp.data.share.ImportFailureReason
import com.saatxi.eatapp.data.share.ImportOutcome
import com.saatxi.eatapp.data.share.RestaurantImportReader
import com.saatxi.eatapp.data.share.readContentUriCapped
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class ImportDecision { ADD, SKIP, REPLACE }

data class ImportCandidate(
    val restaurant: Restaurant,
    /** The existing row this looks like a duplicate of (by name + address), or null. */
    val duplicateOf: Restaurant?,
    val decision: ImportDecision
)

data class RestaurantImportUiState(
    val isLoading: Boolean = true,
    val error: ImportFailureReason? = null,
    val candidates: List<ImportCandidate> = emptyList(),
    val skippedInvalidCount: Int = 0,
    val isImporting: Boolean = false
)

/**
 * Loads and validates the file at [uri], flags likely duplicates against
 * what's already in [repository], and — once the user has reviewed and
 * confirmed — writes the chosen decisions. Nothing is written before
 * [onConfirm] is called: the confirmation screen is the last line of defence
 * against a file that isn't what it claims to be.
 */
class RestaurantImportViewModel(
    private val appContext: Context,
    private val repository: RestaurantRepository,
    private val uri: Uri
) : ViewModel() {

    private val _uiState = MutableStateFlow(RestaurantImportUiState())
    val uiState: StateFlow<RestaurantImportUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            when (val outcome = withContext(Dispatchers.IO) { loadAndValidate() }) {
                is ImportOutcome.Error -> _uiState.update { it.copy(isLoading = false, error = outcome.reason) }
                is ImportOutcome.Success -> {
                    val existing = repository.observeFiltered(query = null, minRating = null, cuisineType = null).first()
                    val candidates = outcome.restaurants.map { candidate ->
                        val duplicate = existing.find { it.isLikelyDuplicateOf(candidate) }
                        ImportCandidate(
                            restaurant = candidate,
                            duplicateOf = duplicate,
                            decision = if (duplicate != null) ImportDecision.SKIP else ImportDecision.ADD
                        )
                    }
                    _uiState.update {
                        it.copy(isLoading = false, candidates = candidates, skippedInvalidCount = outcome.skippedCount)
                    }
                }
            }
        }
    }

    private fun loadAndValidate(): ImportOutcome =
        when (val content = readContentUriCapped(appContext, uri)) {
            is ContentReadResult.TooLarge -> ImportOutcome.Error(ImportFailureReason.TOO_LARGE)
            is ContentReadResult.IoError -> ImportOutcome.Error(ImportFailureReason.IO_ERROR)
            is ContentReadResult.Success -> RestaurantImportReader.read(content.text)
        }

    fun onDecisionChange(index: Int, decision: ImportDecision) {
        _uiState.update { state ->
            state.copy(
                candidates = state.candidates.mapIndexed { i, candidate ->
                    if (i == index) candidate.copy(decision = decision) else candidate
                }
            )
        }
    }

    fun onConfirm(onDone: () -> Unit) {
        val candidates = _uiState.value.candidates
        viewModelScope.launch {
            _uiState.update { it.copy(isImporting = true) }
            candidates.forEach { candidate ->
                when (candidate.decision) {
                    ImportDecision.ADD -> repository.insert(candidate.restaurant)
                    ImportDecision.REPLACE -> candidate.duplicateOf?.let {
                        repository.update(candidate.restaurant.copy(id = it.id))
                    }
                    ImportDecision.SKIP -> Unit
                }
            }
            onDone()
        }
    }
}

private fun Restaurant.isLikelyDuplicateOf(other: Restaurant): Boolean {
    val sameName = name.trim().equals(other.name.trim(), ignoreCase = true)
    val sameAddress = address?.trim().orEmpty().equals(other.address?.trim().orEmpty(), ignoreCase = true)
    return sameName && sameAddress
}
