package com.saatxi.eatapp.data.prefs

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.ThemeMode
import java.io.File
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * A real temp-file-backed `DataStore<Preferences>` (the same real-thing-over-fake
 * approach `AppLocaleManagerTest` took), not a mock — there's no mocking library
 * in this project (see CLAUDE.md), and DataStore's own file I/O plus the
 * corrupt/stale-value fallbacks in `Preferences.toUserPreferences()` are exactly
 * the parts worth exercising for real rather than stubbing out (F-88).
 */
class DataStoreUserPreferencesRepositoryTest {

    private lateinit var file: File
    private lateinit var dataStore: DataStore<Preferences>
    private lateinit var repository: DataStoreUserPreferencesRepository

    @Before
    fun setUp() {
        file = File.createTempFile("test", ".preferences_pb")
        dataStore = PreferenceDataStoreFactory.create(produceFile = { file })
        repository = DataStoreUserPreferencesRepository(dataStore)
    }

    @After
    fun tearDown() {
        file.delete()
    }

    @Test
    fun `defaults before anything has been written`() = runTest {
        assertEquals(UserPreferences.Defaults, repository.preferences.first())
    }

    @Test
    fun `setPalette then read back`() = runTest {
        repository.setPalette(AppPalette.INDIGO)

        assertEquals(AppPalette.INDIGO, repository.preferences.first().palette)
    }

    @Test
    fun `setThemeMode then read back`() = runTest {
        repository.setThemeMode(ThemeMode.DARK)

        assertEquals(ThemeMode.DARK, repository.preferences.first().themeMode)
    }

    @Test
    fun `toggleFavorite adds the id, then removes it on a second call`() = runTest {
        repository.toggleFavorite(42L)
        assertEquals(setOf(42L), repository.preferences.first().favoriteIds)

        repository.toggleFavorite(42L)
        assertEquals(emptySet<Long>(), repository.preferences.first().favoriteIds)
    }

    @Test
    fun `toggleFavorite leaves other stored ids untouched`() = runTest {
        repository.toggleFavorite(1L)
        repository.toggleFavorite(2L)

        assertEquals(setOf(1L, 2L), repository.preferences.first().favoriteIds)
    }

    @Test
    fun `falls back to the default palette when the stored name is not a recognised entry`() = runTest {
        // Simulates a palette renamed or removed between releases, orphaning an
        // existing install's stored value — the same degrade-gracefully contract
        // CLAUDE.md documents for an unrecognised cuisine key.
        dataStore.edit { it[stringPreferencesKey("palette")] = "NO_LONGER_A_PALETTE" }

        assertEquals(AppPalette.Default, repository.preferences.first().palette)
    }

    @Test
    fun `falls back to the default theme mode when the stored value is a removed enum entry`() = runTest {
        // The exact real case F-76-F-79's review traced through by hand: SYSTEM
        // was a valid ThemeMode until it was removed, so an existing install can
        // still have it on disk.
        dataStore.edit { it[stringPreferencesKey("theme_mode")] = "SYSTEM" }

        assertEquals(ThemeMode.Default, repository.preferences.first().themeMode)
    }

    @Test
    fun `ignores a favorite id that is not a valid number`() = runTest {
        dataStore.edit { it[stringSetPreferencesKey("favorite_ids")] = setOf("7", "not-a-number") }

        assertEquals(setOf(7L), repository.preferences.first().favoriteIds)
    }
}
