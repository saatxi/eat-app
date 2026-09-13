package com.saatxi.eatapp.ui.edit

import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.local.Photo
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.normalizeInstagramHandle
import com.saatxi.eatapp.data.local.normalizeTagName
import com.saatxi.eatapp.data.local.normalizeWebsite
import com.saatxi.eatapp.data.mapslink.MapsLinkResolver
import com.saatxi.eatapp.data.photo.RestaurantPhotoStorage
import com.saatxi.eatapp.data.photo.deleteRestaurantPhotoFile
import com.saatxi.eatapp.data.repository.RestaurantRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import java.util.UUID
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Widest price scale a restaurant can hold; see [Restaurant]. */
private const val MAX_PRICE_RANGE = 4

data class RestaurantEditUiState(
    /** Null while an existing restaurant is still loading in edit mode. */
    val isLoading: Boolean = false,
    val name: String = "",
    val cuisineType: String? = null,
    val streetAddress: String = "",
    val city: String = "",
    val region: String = "",
    val country: String = "",
    val priceRange: Int = 0,
    val website: String = "",
    val instagram: String = "",
    /** Already-persisted photos of the restaurant being edited, in display order; empty when adding a new one. */
    val existingPhotos: List<Photo> = emptyList(),
    /** [existingPhotos] whose [Photo.id] is in here are hidden and deleted (row + file) on [RestaurantEditViewModel.onSave]. */
    val removedPhotoIds: Set<String> = emptySet(),
    /**
     * Freshly picked photos, already copied into permanent storage (unlike
     * the old single-photo field, which deferred the copy to save time) —
     * matching `LogVisitViewModel`'s pattern, since a carousel needs each
     * pick resolved to its own path as soon as it's made. Persisted as new
     * [Photo] rows on save.
     */
    val newPhotoPaths: List<String> = emptyList(),
    val nameError: Boolean = false,
    val cuisineError: Boolean = false,
    val websiteError: Boolean = false,
    val instagramError: Boolean = false,
    val tags: List<String> = emptyList(),
    /** True while [RestaurantEditViewModel.onImportFromLink] (or a shared-link cold start) is resolving a Google Maps link. */
    val isResolvingLink: Boolean = false
) {
    /** Every photo the carousel should show: surviving persisted ones first, then freshly added ones. */
    val photoPaths: List<String>
        get() = existingPhotos.filterNot { it.id in removedPhotoIds }.map { it.path } + newPhotoPaths
}

/**
 * Backs both "add" (`restaurantId == null`) and "edit" (`restaurantId` set) —
 * the two only differ in whether a row is loaded to prefill the form and
 * whether saving inserts or updates. This form is place-level data only
 * (name, cuisine, address, price, links, tags, photo): rating/visited/notes
 * moved to the Visit timeline (`ui/detail/`, `ui/logvisit/`) — a new
 * restaurant starts with zero visits, which is exactly what "want to try"
 * means, so there's nothing to ask for here.
 */
@HiltViewModel
class RestaurantEditViewModel @Inject constructor(
    private val repository: RestaurantRepository,
    private val photoStorage: RestaurantPhotoStorage,
    private val mapsLinkResolver: MapsLinkResolver,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val restaurantId: String? = savedStateHandle["restaurantId"]
    // Non-null only when reached via Routes.IMPORT_LINK (the share-sheet cold
    // start) — see EatAppNavHost's importLinkRoute()/ARG_LINK_URL.
    private val sharedLinkUrl: String? = savedStateHandle.get<String>("linkUrl")?.let(Uri::decode)

    private val _uiState = MutableStateFlow(RestaurantEditUiState(isLoading = restaurantId != null))
    val uiState: StateFlow<RestaurantEditUiState> = _uiState.asStateFlow()

    val isEditingExisting: Boolean get() = restaurantId != null

    /** Existing tag names across all restaurants, offered as suggestions while typing a new one. */
    val tagSuggestions: StateFlow<List<String>> = repository.observeAllTagNames()
        .stateIn(scope = viewModelScope, started = SharingStarted.WhileSubscribed(5_000), initialValue = emptyList())

    /** Existing city/region/country values across all restaurants, offered as suggestions while typing. */
    val citySuggestions: StateFlow<List<String>> = repository.observeCities()
        .stateIn(scope = viewModelScope, started = SharingStarted.WhileSubscribed(5_000), initialValue = emptyList())
    val regionSuggestions: StateFlow<List<String>> = repository.observeRegions()
        .stateIn(scope = viewModelScope, started = SharingStarted.WhileSubscribed(5_000), initialValue = emptyList())
    val countrySuggestions: StateFlow<List<String>> = repository.observeCountries()
        .stateIn(scope = viewModelScope, started = SharingStarted.WhileSubscribed(5_000), initialValue = emptyList())

    init {
        val id = restaurantId
        if (id != null) {
            viewModelScope.launch {
                val restaurant = repository.observeById(id).first()
                if (restaurant != null) {
                    val tags = repository.observeTagNames(id).first()
                    val photos = repository.observePhotosForRestaurant(id).first()
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            name = restaurant.name,
                            cuisineType = restaurant.cuisineType,
                            streetAddress = restaurant.streetAddress.orEmpty(),
                            city = restaurant.city.orEmpty(),
                            region = restaurant.region.orEmpty(),
                            country = restaurant.country.orEmpty(),
                            priceRange = restaurant.priceRange,
                            website = restaurant.website.orEmpty(),
                            instagram = restaurant.instagram.orEmpty(),
                            existingPhotos = photos,
                            tags = tags
                        )
                    }
                } else {
                    _uiState.update { it.copy(isLoading = false) }
                }
            }
        }
        sharedLinkUrl?.let(::onImportFromLink)
    }

    fun onNameChange(name: String) {
        _uiState.update { it.copy(name = name, nameError = false) }
    }

    fun onCuisineChange(cuisineType: String) {
        _uiState.update { it.copy(cuisineType = cuisineType, cuisineError = false) }
    }

    fun onStreetAddressChange(streetAddress: String) {
        _uiState.update { it.copy(streetAddress = streetAddress) }
    }

    fun onCityChange(city: String) {
        _uiState.update { it.copy(city = city) }
    }

    fun onRegionChange(region: String) {
        _uiState.update { it.copy(region = region) }
    }

    fun onCountryChange(country: String) {
        _uiState.update { it.copy(country = country) }
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

    /**
     * Resolves a Google Maps share link (`share.google`, `maps.app.goo.gl`...)
     * and, if it recognises the link, prefills the name (only when still
     * blank, so this never overwrites something the user already typed) and
     * the website field with the resolved URL. The raw link is written to
     * Website immediately so the field isn't left empty while resolving, and
     * the resolution itself can never block or fail loudly — an unreachable
     * or unrecognised link just leaves the raw link there for the user to
     * complete the rest of the form manually.
     */
    fun onImportFromLink(url: String) {
        val trimmed = url.trim()
        if (trimmed.isEmpty()) return
        _uiState.update { it.copy(website = trimmed, isResolvingLink = true) }
        viewModelScope.launch {
            val place = mapsLinkResolver.resolve(trimmed)
            _uiState.update { state ->
                state.copy(
                    isResolvingLink = false,
                    name = if (state.name.isBlank()) place?.name ?: state.name else state.name,
                    website = place?.resolvedUrl ?: state.website
                )
            }
        }
    }

    /**
     * Copies [uri] into permanent storage right away — like
     * [com.saatxi.eatapp.ui.logvisit.LogVisitViewModel]'s photos, unlike the
     * old single deferred pick — and appends the resulting path to the
     * carousel. A copy that fails is silently dropped.
     */
    fun onPhotoPicked(uri: Uri) {
        viewModelScope.launch {
            val path = photoStorage.copy(uri) ?: return@launch
            _uiState.update { it.copy(newPhotoPaths = it.newPhotoPaths + path) }
        }
    }

    /**
     * Removes one tile from the carousel. A still-persisted photo is only
     * hidden and queued for deletion on [onSave] (so cancelling the form
     * leaves it untouched); a freshly picked one that was never saved has
     * nothing left referencing it, so its copied file is deleted immediately.
     */
    fun onRemovePhoto(path: String) {
        val state = _uiState.value
        val existingMatch = state.existingPhotos.firstOrNull { it.path == path && it.id !in state.removedPhotoIds }
        if (existingMatch != null) {
            _uiState.update { it.copy(removedPhotoIds = it.removedPhotoIds + existingMatch.id) }
        } else {
            _uiState.update { it.copy(newPhotoPaths = it.newPhotoPaths.filterNot { existing -> existing == path }) }
            deleteRestaurantPhotoFile(path)
        }
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
            val id = restaurantId ?: UUID.randomUUID().toString()
            val restaurant = Restaurant(
                id = id,
                name = trimmedName,
                cuisineType = state.cuisineType,
                streetAddress = state.streetAddress.trim().takeIf { it.isNotBlank() },
                city = state.city.trim().takeIf { it.isNotBlank() },
                region = state.region.trim().takeIf { it.isNotBlank() },
                country = state.country.trim().takeIf { it.isNotBlank() },
                priceRange = state.priceRange,
                website = website,
                instagram = instagram
            )

            if (restaurantId != null) {
                repository.update(restaurant, state.tags)
            } else {
                repository.insert(restaurant, state.tags)
            }
            state.removedPhotoIds.forEach { repository.deletePhoto(it) }
            repository.addRestaurantPhotos(id, state.newPhotoPaths)
            onSaved()
        }
    }
}
