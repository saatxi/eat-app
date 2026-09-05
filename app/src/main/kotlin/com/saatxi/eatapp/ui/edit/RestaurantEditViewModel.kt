package com.saatxi.eatapp.ui.edit

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.normalizeInstagramHandle
import com.saatxi.eatapp.data.local.normalizeTagName
import com.saatxi.eatapp.data.local.normalizeWebsite
import com.saatxi.eatapp.data.photo.RestaurantPhotoStorage
import com.saatxi.eatapp.data.repository.RestaurantRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Widest rating/price scale a restaurant can hold; see [Restaurant]. */
private const val MAX_RATING = 5
private const val MAX_PRICE_RANGE = 4

data class RestaurantEditUiState(
    /** Null while an existing restaurant is still loading in edit mode. */
    val isLoading: Boolean = false,
    val name: String = "",
    val cuisineType: String? = null,
    val address: String = "",
    val notes: String = "",
    val visited: Boolean = true,
    val rating: Int = 0,
    val priceRange: Int = 0,
    val website: String = "",
    val instagram: String = "",
    /** Already-persisted photo of the restaurant being edited; null when adding a new one. */
    val existingPhotoPath: String? = null,
    /** A freshly picked photo, not yet copied into storage — that only happens on [RestaurantEditViewModel.onSave]. */
    val pendingPhotoUri: Uri? = null,
    /** True once the user has cleared [existingPhotoPath] without picking a replacement. */
    val photoRemoved: Boolean = false,
    val nameError: Boolean = false,
    val cuisineError: Boolean = false,
    val websiteError: Boolean = false,
    val instagramError: Boolean = false,
    val tags: List<String> = emptyList()
) {
    /** What the form should preview: a pending pick beats the existing photo, which a removal beats. */
    val previewPhoto: Any?
        get() = pendingPhotoUri ?: existingPhotoPath?.takeUnless { photoRemoved }
}

/**
 * Backs both "add" (`restaurantId == null`) and "edit" (`restaurantId` set) —
 * the two only differ in whether a row is loaded to prefill the form and
 * whether saving inserts or updates.
 */
class RestaurantEditViewModel(
    private val repository: RestaurantRepository,
    private val photoStorage: RestaurantPhotoStorage,
    private val restaurantId: Long?
) : ViewModel() {

    private val _uiState = MutableStateFlow(RestaurantEditUiState(isLoading = restaurantId != null))
    val uiState: StateFlow<RestaurantEditUiState> = _uiState.asStateFlow()

    val isEditingExisting: Boolean get() = restaurantId != null

    /** Existing tag names across all restaurants, offered as suggestions while typing a new one. */
    val tagSuggestions: StateFlow<List<String>> = repository.observeAllTagNames()
        .stateIn(scope = viewModelScope, started = SharingStarted.WhileSubscribed(5_000), initialValue = emptyList())

    init {
        val id = restaurantId
        if (id != null) {
            viewModelScope.launch {
                val restaurant = repository.observeById(id).first()
                if (restaurant != null) {
                    val tags = repository.observeTagNames(id).first()
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            name = restaurant.name,
                            cuisineType = restaurant.cuisineType,
                            address = restaurant.address.orEmpty(),
                            notes = restaurant.notes.orEmpty(),
                            visited = restaurant.visited,
                            rating = restaurant.rating,
                            priceRange = restaurant.priceRange,
                            website = restaurant.website.orEmpty(),
                            instagram = restaurant.instagram.orEmpty(),
                            existingPhotoPath = restaurant.photoPath,
                            tags = tags
                        )
                    }
                } else {
                    _uiState.update { it.copy(isLoading = false) }
                }
            }
        }
    }

    fun onNameChange(name: String) {
        _uiState.update { it.copy(name = name, nameError = false) }
    }

    fun onCuisineChange(cuisineType: String) {
        _uiState.update { it.copy(cuisineType = cuisineType, cuisineError = false) }
    }

    fun onAddressChange(address: String) {
        _uiState.update { it.copy(address = address) }
    }

    fun onNotesChange(notes: String) {
        _uiState.update { it.copy(notes = notes) }
    }

    fun onVisitedChange(visited: Boolean) {
        _uiState.update { it.copy(visited = visited) }
    }

    fun onRatingChange(rating: Int) {
        _uiState.update { it.copy(rating = rating.coerceIn(0, MAX_RATING)) }
    }

    fun onPriceRangeChange(priceRange: Int) {
        _uiState.update { it.copy(priceRange = priceRange.coerceIn(0, MAX_PRICE_RANGE)) }
    }

    fun onWebsiteChange(website: String) {
        _uiState.update { it.copy(website = website, websiteError = false) }
    }

    fun onInstagramChange(instagram: String) {
        _uiState.update { it.copy(instagram = instagram, instagramError = false) }
    }

    /** [uri] is only ever held in memory until [onSave] copies it — see [RestaurantEditUiState.pendingPhotoUri]. */
    fun onPhotoPicked(uri: Uri) {
        _uiState.update { it.copy(pendingPhotoUri = uri, photoRemoved = false) }
    }

    fun onRemovePhoto() {
        _uiState.update { it.copy(pendingPhotoUri = null, photoRemoved = true) }
    }

    /** Ignored (no-op) when [raw] fails validation or already matches a tag already added, case-insensitively. */
    fun onAddTag(raw: String) {
        val normalized = normalizeTagName(raw) ?: return
        _uiState.update { state ->
            if (state.tags.any { it.equals(normalized, ignoreCase = true) }) state
            else state.copy(tags = state.tags + normalized)
        }
    }

    fun onRemoveTag(name: String) {
        _uiState.update { it.copy(tags = it.tags.filterNot { tag -> tag == name }) }
    }

    /**
     * Validates the form and, if valid, inserts or updates the restaurant and
     * calls [onSaved]. Otherwise flags the offending fields in [uiState] and
     * returns without saving.
     */
    fun onSave(onSaved: () -> Unit) {
        val state = _uiState.value

        val trimmedName = state.name.trim()
        val website = state.website.takeIf { it.isNotBlank() }?.let(::normalizeWebsite)
        val instagram = state.instagram.takeIf { it.isNotBlank() }?.let(::normalizeInstagramHandle)

        val nameError = trimmedName.isEmpty()
        val cuisineError = state.cuisineType == null
        val websiteError = state.website.isNotBlank() && website == null
        val instagramError = state.instagram.isNotBlank() && instagram == null

        if (nameError || cuisineError || websiteError || instagramError) {
            _uiState.update {
                it.copy(
                    nameError = nameError,
                    cuisineError = cuisineError,
                    websiteError = websiteError,
                    instagramError = instagramError
                )
            }
            return
        }

        viewModelScope.launch {
            // A pending pick is only copied into permanent storage now, at the moment the
            // restaurant is actually saved — not when it was picked — so cancelling the
            // form (back, without saving) never leaves an orphaned file behind. A copy
            // that fails (an unreadable or corrupt source) falls back to whatever photo
            // was already there rather than losing it over one bad pick.
            val photoPath = when {
                state.pendingPhotoUri != null -> photoStorage.copy(state.pendingPhotoUri) ?: state.existingPhotoPath
                state.photoRemoved -> null
                else -> state.existingPhotoPath
            }

            val restaurant = Restaurant(
                id = restaurantId ?: 0,
                name = trimmedName,
                cuisineType = state.cuisineType,
                address = state.address.trim().takeIf { it.isNotBlank() },
                notes = state.notes.trim().takeIf { it.isNotBlank() },
                visited = state.visited,
                rating = state.rating,
                priceRange = state.priceRange,
                website = website,
                instagram = instagram,
                photoPath = photoPath
            )

            if (restaurantId != null) {
                repository.update(restaurant, state.tags)
            } else {
                repository.insert(restaurant, state.tags)
            }
            onSaved()
        }
    }
}
