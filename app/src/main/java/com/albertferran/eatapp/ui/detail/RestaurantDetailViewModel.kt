package com.albertferran.eatapp.ui.detail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.repository.RestaurantRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class RestaurantDetailViewModel(
    private val repository: RestaurantRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val restaurantId: Long = checkNotNull(savedStateHandle["restaurantId"])

    val restaurant: StateFlow<Restaurant?> = repository.observeById(restaurantId)
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = null
        )

    fun delete(onDeleted: () -> Unit) {
        val current = restaurant.value ?: return
        viewModelScope.launch {
            repository.delete(current)
            onDeleted()
        }
    }
}
