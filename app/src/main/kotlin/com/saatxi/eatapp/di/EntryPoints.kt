package com.saatxi.eatapp.di

import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * [WantToTryWidget][com.saatxi.eatapp.widget.WantToTryWidget] is constructed
 * by the Glance/AppWidget framework, not by Hilt, so it has no injection
 * point of its own to receive a `@HiltViewModel`-style constructor. This lets
 * it reach into the same Hilt-managed [RestaurantRepository] singleton from
 * the application `Context` instead of building its own.
 *
 * [RestaurantDetailScreen][com.saatxi.eatapp.ui.detail.RestaurantDetailScreen]
 * reuses the same entry point for its two-pane case: there the restaurant id
 * comes from the pane navigator rather than a nav-backstack entry, so
 * `hiltViewModel()`'s normal SavedStateHandle-from-backstack wiring has
 * nothing to read it from, and the screen builds a one-off
 * `SavedStateHandle` + manual `ViewModelProvider.Factory` instead — see that
 * screen for details.
 */
@EntryPoint
@InstallIn(SingletonComponent::class)
interface RestaurantRepositoryEntryPoint {
    fun restaurantRepository(): RestaurantRepository
    fun userPreferencesRepository(): UserPreferencesRepository
}
