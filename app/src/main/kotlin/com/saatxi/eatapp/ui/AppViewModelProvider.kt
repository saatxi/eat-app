package com.saatxi.eatapp.ui

import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.CreationExtras
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.saatxi.eatapp.EatApplication
import com.saatxi.eatapp.ui.detail.RestaurantDetailViewModel
import com.saatxi.eatapp.ui.favorites.FavoritesViewModel
import com.saatxi.eatapp.ui.list.RestaurantListViewModel
import com.saatxi.eatapp.ui.roulette.RouletteViewModel
import com.saatxi.eatapp.ui.settings.SettingsViewModel

fun CreationExtras.eatApplication(): EatApplication =
    this[APPLICATION_KEY] as EatApplication

object AppViewModelProvider {
    val Factory = viewModelFactory {
        initializer {
            RestaurantListViewModel(
                eatApplication().repository,
                eatApplication().syncManager,
                eatApplication().userPreferences
            )
        }
        initializer {
            RestaurantDetailViewModel(
                eatApplication().repository,
                eatApplication().userPreferences,
                createSavedStateHandle()
            )
        }
        initializer {
            SettingsViewModel(
                eatApplication().userPreferences,
                eatApplication().syncManager,
                eatApplication().localeManager
            )
        }
        initializer {
            FavoritesViewModel(eatApplication().repository, eatApplication().userPreferences)
        }
        initializer {
            RouletteViewModel(eatApplication().repository, eatApplication().userPreferences)
        }
    }
}
