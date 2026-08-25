package com.albertferran.eatapp.ui.detail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.repository.RestaurantRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn

class RestaurantDetailViewModel(
    repository: RestaurantRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val restaurantId: Long = checkNotNull(savedStateHandle["restaurantId"])

    val restaurant: StateFlow<Restaurant?> = repository.observeById(restaurantId)
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = null
        )
}
