package com.saatxi.eatapp.ui

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.CreationExtras
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.saatxi.eatapp.EatApplication
import com.saatxi.eatapp.ui.detail.RestaurantDetailViewModel
import com.saatxi.eatapp.ui.edit.RestaurantEditViewModel
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
                eatApplication().userPreferences
            )
        }
        initializer {
            RestaurantDetailViewModel(
                eatApplication().repository,
                eatApplication().userPreferences,
                restaurantId = checkNotNull(createSavedStateHandle()["restaurantId"])
            )
        }
        initializer {
            SettingsViewModel(
                eatApplication().userPreferences,
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

    /**
     * Used only by the two-pane list-detail layout: there the selected
     * restaurant id comes from the pane navigator's own state, not from a
     * nav-backstack entry's [android.os.Bundle], so there is no
     * [androidx.lifecycle.SavedStateHandle] to read it from.
     */
    fun detailViewModelFactory(restaurantId: Long): ViewModelProvider.Factory = viewModelFactory {
        initializer {
            RestaurantDetailViewModel(
                eatApplication().repository,
                eatApplication().userPreferences,
                restaurantId = restaurantId
            )
        }
    }

    /** `restaurantId == null` means "add a new restaurant" rather than edit an existing one. */
    fun editViewModelFactory(restaurantId: Long?): ViewModelProvider.Factory = viewModelFactory {
        initializer {
            RestaurantEditViewModel(eatApplication().repository, restaurantId = restaurantId)
        }
    }
}
