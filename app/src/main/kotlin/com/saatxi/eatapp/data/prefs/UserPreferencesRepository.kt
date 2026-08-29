package com.saatxi.eatapp.data.prefs

import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.ThemeMode
import kotlinx.coroutines.flow.Flow

/**
 * Everything the user has chosen, as opposed to everything that was synced.
 *
 * Kept apart from `RestaurantRepository` on purpose: that one is a cache of a
 * re-downloadable file and is wiped whenever the schema changes, which is the
 * correct policy for a cache and the wrong one for the two things here.
 */
data class UserPreferences(
    val palette: AppPalette,
    val themeMode: ThemeMode,
    /**
     * Ids of favourited restaurants. These are the ids from the source `.db`,
     * which the importer preserves verbatim, so a favourite survives a sync.
     */
    val favoriteIds: Set<Long>
) {
    companion object {
        /** What the app shows before the stored values have been read back. */
        val Defaults = UserPreferences(
            palette = AppPalette.Default,
            themeMode = ThemeMode.Default,
            favoriteIds = emptySet()
        )
    }
}

interface UserPreferencesRepository {

    val preferences: Flow<UserPreferences>

    suspend fun setPalette(palette: AppPalette)

    suspend fun setThemeMode(themeMode: ThemeMode)

    /** Adds the id if absent, removes it if present. */
    suspend fun toggleFavorite(restaurantId: Long)
}
