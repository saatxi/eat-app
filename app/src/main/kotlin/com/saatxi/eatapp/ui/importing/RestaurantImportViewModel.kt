package com.saatxi.eatapp.ui.importing

import android.content.Context
import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.data.share.ContentReadResult
import com.saatxi.eatapp.data.share.ImportFailureReason
import com.saatxi.eatapp.data.share.ImportOutcome
import com.saatxi.eatapp.data.share.RestaurantImportReader
import com.saatxi.eatapp.data.share.VisitExport
import com.saatxi.eatapp.data.share.readContentUriCapped
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
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
    val tags: List<String>,
    val visits: List<VisitExport>,
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
@HiltViewModel
class RestaurantImportViewModel @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val repository: RestaurantRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    // The nav graph's "uri" arg arrives Uri-encoded (see EatAppNavHost's
    // importRoute/decoding), the same round trip it does there, so this
    // ViewModel doesn't need a raw android.net.Uri passed in directly.
    private val uri: Uri = Uri.parse(Uri.decode(checkNotNull(savedStateHandle.get<String>("uri"))))

    private val _uiState = MutableStateFlow(RestaurantImportUiState())
    val uiState: StateFlow<RestaurantImportUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            when (val outcome = withContext(Dispatchers.IO) { loadAndValidate() }) {
                is ImportOutcome.Error -> _uiState.update { it.copy(isLoading = false, error = outcome.reason) }
                is ImportOutcome.Success -> {
                    val existing = repository.observeFiltered(query = null, minRating = null, cuisineType = null).first()
                    val candidates = outcome.restaurants.map { imported ->
                        val duplicate = existing.find { it.isLikelyDuplicateOf(imported.restaurant) }
                        ImportCandidate(
                            restaurant = imported.restaurant,
                            tags = imported.tags,
                            visits = imported.visits,
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
                val restaurantId = when (candidate.decision) {
                    ImportDecision.ADD -> {
                        repository.insert(candidate.restaurant, candidate.tags)
                        candidate.restaurant.id
                    }
                    ImportDecision.REPLACE -> candidate.duplicateOf?.let {
                        repository.update(candidate.restaurant.copy(id = it.id), candidate.tags)
                        it.id
                    }
                    ImportDecision.SKIP -> null
                }
                if (restaurantId != null) {
                    candidate.visits.forEach { visit ->
                        repository.addVisit(restaurantId, visit.visitDate, visit.rating, visit.notes, visit.priceRange)
                    }
                }
            }
            onDone()
        }
    }
}

private fun Restaurant.isLikelyDuplicateOf(other: Restaurant): Boolean {
    val sameName = name.trim().equals(other.name.trim(), ignoreCase = true)
    val thisAddress = streetAddress?.trim().orEmpty()
    val otherAddress = other.streetAddress?.trim().orEmpty()
    // A missing address on either side (e.g. an imported row that never had
    // one recorded) shouldn't block a match on name alone — only compare
    // addresses when both rows actually have one, otherwise a same-name
    // restaurant with no address on one side would wrongly import as a
    // second copy instead of being flagged as a duplicate.
    val sameAddress = thisAddress.isEmpty() || otherAddress.isEmpty() || thisAddress.equals(otherAddress, ignoreCase = true)
    return sameName && sameAddress
}
