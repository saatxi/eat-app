package com.albertferran.eatapp.ui.addedit

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.repository.RestaurantRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate

data class AddEditRestaurantUiState(
    val id: Long = 0L,
    val name: String = "",
    val cuisineType: String = "",
    val address: String = "",
    val rating: Int = 0,
    val priceRange: Int = 1,
    val notes: String = "",
    val visitDate: LocalDate = LocalDate.now(),
    val photoUri: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val nameError: Boolean = false,
    val isSaved: Boolean = false
)

class AddEditRestaurantViewModel(
    private val repository: RestaurantRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val restaurantId: Long = savedStateHandle.get<Long>("restaurantId") ?: NEW_RESTAURANT_ID

    private val _uiState = MutableStateFlow(AddEditRestaurantUiState(id = restaurantId))
    val uiState: StateFlow<AddEditRestaurantUiState> = _uiState.asStateFlow()

    init {
        if (restaurantId != NEW_RESTAURANT_ID) {
            viewModelScope.launch {
                repository.observeById(restaurantId).collect { restaurant ->
                    restaurant?.let { _uiState.value = it.toUiState() }
                }
            }
        }
    }

    fun onNameChange(value: String) = _uiState.update { it.copy(name = value, nameError = false) }
    fun onCuisineTypeChange(value: String) = _uiState.update { it.copy(cuisineType = value) }
    fun onAddressChange(value: String) = _uiState.update { it.copy(address = value) }
    fun onRatingChange(value: Int) = _uiState.update { it.copy(rating = value) }
    fun onPriceRangeChange(value: Int) = _uiState.update { it.copy(priceRange = value) }
    fun onNotesChange(value: String) = _uiState.update { it.copy(notes = value) }
    fun onVisitDateChange(value: LocalDate) = _uiState.update { it.copy(visitDate = value) }
    fun onPhotoUriChange(value: String?) = _uiState.update { it.copy(photoUri = value) }

    fun save() {
        val state = _uiState.value
        if (state.name.isBlank()) {
            _uiState.update { it.copy(nameError = true) }
            return
        }
        viewModelScope.launch {
            repository.upsert(state.toRestaurant())
            _uiState.update { it.copy(isSaved = true) }
        }
    }

    companion object {
        const val NEW_RESTAURANT_ID = -1L
    }
}

private fun Restaurant.toUiState() = AddEditRestaurantUiState(
    id = id,
    name = name,
    cuisineType = cuisineType,
    address = address.orEmpty(),
    rating = rating,
    priceRange = priceRange,
    notes = notes,
    visitDate = visitDate,
    photoUri = photoUri,
    createdAt = createdAt
)

private fun AddEditRestaurantUiState.toRestaurant() = Restaurant(
    id = if (id == AddEditRestaurantViewModel.NEW_RESTAURANT_ID) 0L else id,
    name = name.trim(),
    cuisineType = cuisineType.trim(),
    address = address.trim().ifBlank { null },
    rating = rating,
    priceRange = priceRange,
    notes = notes.trim(),
    visitDate = visitDate,
    photoUri = photoUri,
    createdAt = createdAt
)
