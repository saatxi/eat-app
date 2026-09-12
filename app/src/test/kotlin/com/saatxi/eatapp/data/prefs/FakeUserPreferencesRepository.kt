package com.saatxi.eatapp.data.prefs

import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.ThemeMode
import kotlinx.coroutines.flow.MutableStateFlow

/** Replays whatever a test pushes into [preferences] and records favourite writes. Shared across ViewModel tests. */
class FakeUserPreferencesRepository : UserPreferencesRepository {

    override val preferences = MutableStateFlow(UserPreferences.Defaults)

    override suspend fun setPalette(palette: AppPalette) {
        preferences.value = preferences.value.copy(palette = palette)
    }

    override suspend fun setThemeMode(themeMode: ThemeMode) {
        preferences.value = preferences.value.copy(themeMode = themeMode)
    }

    override suspend fun toggleFavorite(restaurantId: String) {
        val current = preferences.value.favoriteIds
        preferences.value = preferences.value.copy(
            favoriteIds = if (restaurantId in current) current - restaurantId else current + restaurantId
        )
    }
}
