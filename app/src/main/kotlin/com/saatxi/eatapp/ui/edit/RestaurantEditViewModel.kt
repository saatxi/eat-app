package com.saatxi.eatapp.ui.edit

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.normalizeInstagramHandle
import com.saatxi.eatapp.data.local.normalizeWebsite
import com.saatxi.eatapp.data.repository.RestaurantRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
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
    val rating: Int = 0,
    val priceRange: Int = 0,
    val website: String = "",
    val instagram: String = "",
    val nameError: Boolean = false,
    val cuisineError: Boolean = false,
    val websiteError: Boolean = false,
    val instagramError: Boolean = false
)

/**
 * Backs both "add" (`restaurantId == null`) and "edit" (`restaurantId` set) —
 * the two only differ in whether a row is loaded to prefill the form and
 * whether saving inserts or updates.
 */
class RestaurantEditViewModel(
    private val repository: RestaurantRepository,
    private val restaurantId: Long?
) : ViewModel() {

    private val _uiState = MutableStateFlow(RestaurantEditUiState(isLoading = restaurantId != null))
    val uiState: StateFlow<RestaurantEditUiState> = _uiState.asStateFlow()

    val isEditingExisting: Boolean get() = restaurantId != null

    init {
        val id = restaurantId
        if (id != null) {
            viewModelScope.launch {
                val restaurant = repository.observeById(id).first()
                if (restaurant != null) {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            name = restaurant.name,
                            cuisineType = restaurant.cuisineType,
                            address = restaurant.address.orEmpty(),
                            rating = restaurant.rating,
                            priceRange = restaurant.priceRange,
                            website = restaurant.website.orEmpty(),
                            instagram = restaurant.instagram.orEmpty()
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

        val restaurant = Restaurant(
            id = restaurantId ?: 0,
            name = trimmedName,
            cuisineType = state.cuisineType,
            address = state.address.trim().takeIf { it.isNotBlank() },
            rating = state.rating,
            priceRange = state.priceRange,
            website = website,
            instagram = instagram
        )

        viewModelScope.launch {
            if (restaurantId != null) {
                repository.update(restaurant)
            } else {
                repository.insert(restaurant)
            }
            onSaved()
        }
    }
}
