package com.albertferran.eatapp.data.prefs

import android.content.Context
import android.util.Log
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.albertferran.eatapp.ui.theme.AppPalette
import com.albertferran.eatapp.ui.theme.ThemeMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import java.io.IOException

private const val TAG = "EatApp.Prefs"

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "user_prefs")

private object Keys {
    val PALETTE = stringPreferencesKey("palette")
    val THEME_MODE = stringPreferencesKey("theme_mode")

    /**
     * DataStore has no `Set<Long>` type, so the ids are stored as strings. The
     * alternative — one boolean key per restaurant — would leak deleted
     * restaurants into the file forever.
     */
    val FAVORITE_IDS = stringSetPreferencesKey("favorite_ids")
}

class DataStoreUserPreferencesRepository(
    private val dataStore: DataStore<Preferences>
) : UserPreferencesRepository {

    constructor(context: Context) : this(context.applicationContext.dataStore)

    override val preferences: Flow<UserPreferences> = dataStore.data
        .catch { throwable ->
            // A corrupt or unreadable file must not take the whole app down with
            // it: the defaults are always a usable state, and the next write
            // repairs the file.
            if (throwable is IOException) {
                Log.w(TAG, "Could not read preferences, falling back to defaults", throwable)
                emit(emptyPreferences())
            } else {
                throw throwable
            }
        }
        .map { it.toUserPreferences() }

    override suspend fun setPalette(palette: AppPalette) {
        dataStore.edit { it[Keys.PALETTE] = palette.name }
    }

    override suspend fun setThemeMode(themeMode: ThemeMode) {
        dataStore.edit { it[Keys.THEME_MODE] = themeMode.name }
    }

    override suspend fun toggleFavorite(restaurantId: Long) {
        dataStore.edit { prefs ->
            val current = prefs[Keys.FAVORITE_IDS].orEmpty()
            val id = restaurantId.toString()
            prefs[Keys.FAVORITE_IDS] = if (id in current) current - id else current + id
        }
    }
}

/**
 * Every stored value is treated as untrusted: an enum renamed between releases,
 * or an id that is no longer a number, degrades to the default instead of
 * throwing. The file outlives any single version of the app.
 */
private fun Preferences.toUserPreferences(): UserPreferences = UserPreferences(
    palette = this[Keys.PALETTE]?.let { name ->
        AppPalette.entries.firstOrNull { it.name == name }
    } ?: AppPalette.Default,
    themeMode = this[Keys.THEME_MODE]?.let { name ->
        ThemeMode.entries.firstOrNull { it.name == name }
    } ?: ThemeMode.Default,
    favoriteIds = this[Keys.FAVORITE_IDS]
        ?.mapNotNullTo(mutableSetOf()) { it.toLongOrNull() }
        .orEmpty()
)
