package com.albertferran.eatapp.ui

import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.CreationExtras
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.albertferran.eatapp.EatApplication
import com.albertferran.eatapp.ui.detail.RestaurantDetailViewModel
import com.albertferran.eatapp.ui.list.RestaurantListViewModel

fun CreationExtras.eatApplication(): EatApplication =
    this[APPLICATION_KEY] as EatApplication

object AppViewModelProvider {
    val Factory = viewModelFactory {
        initializer {
            RestaurantListViewModel(eatApplication().repository, eatApplication().syncManager)
        }
        initializer {
            RestaurantDetailViewModel(eatApplication().repository, createSavedStateHandle())
        }
    }
}
