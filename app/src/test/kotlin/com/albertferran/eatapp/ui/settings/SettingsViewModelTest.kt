package com.albertferran.eatapp.ui.settings

import com.albertferran.eatapp.data.prefs.UserPreferences
import com.albertferran.eatapp.data.prefs.UserPreferencesRepository
import com.albertferran.eatapp.data.sync.DatabaseSyncManager
import com.albertferran.eatapp.data.sync.DatabaseSyncResult
import com.albertferran.eatapp.data.sync.SyncFailureReason
import com.albertferran.eatapp.ui.list.SyncMessage
import com.albertferran.eatapp.ui.theme.AppPalette
import com.albertferran.eatapp.ui.theme.ThemeMode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var preferencesRepository: FakeUserPreferencesRepository
    private lateinit var syncManager: FakeDatabaseSyncManager
    private lateinit var viewModel: SettingsViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        preferencesRepository = FakeUserPreferencesRepository()
        syncManager = FakeDatabaseSyncManager()
        viewModel = SettingsViewModel(preferencesRepository, syncManager)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    /** uiState is a WhileSubscribed flow, so it only updates while collected. */
    private fun TestScope.observeState() {
        backgroundScope.launch(dispatcher) { viewModel.uiState.collect {} }
    }

    @Test
    fun `starts with the stored palette and theme mode`() = runTest {
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(
            palette = AppPalette.GARDEN,
            themeMode = ThemeMode.DARK
        )
        observeState()

        assertEquals(AppPalette.GARDEN, viewModel.uiState.value.palette)
        assertEquals(ThemeMode.DARK, viewModel.uiState.value.themeMode)
    }

    @Test
    fun `changing the palette writes through to the repository`() = runTest {
        observeState()

        viewModel.onPaletteChange(AppPalette.INDIGO)

        assertEquals(AppPalette.INDIGO, preferencesRepository.preferences.value.palette)
        assertEquals(AppPalette.INDIGO, viewModel.uiState.value.palette)
    }

    @Test
    fun `changing the theme mode writes through to the repository`() = runTest {
        observeState()

        viewModel.onThemeModeChange(ThemeMode.LIGHT)

        assertEquals(ThemeMode.LIGHT, preferencesRepository.preferences.value.themeMode)
        assertEquals(ThemeMode.LIGHT, viewModel.uiState.value.themeMode)
    }

    @Test
    fun `syncNow reports success`() = runTest {
        syncManager.result = DatabaseSyncResult.Success(3)
        observeState()

        viewModel.syncNow()

        assertFalse(viewModel.uiState.value.isSyncing)
        assertEquals(SyncMessage.Success(3), viewModel.uiState.value.pendingSyncMessage)
    }

    @Test
    fun `syncNow reports a failure`() = runTest {
        syncManager.result = DatabaseSyncResult.Failure(SyncFailureReason.NETWORK)
        observeState()

        viewModel.syncNow()

        assertEquals(SyncMessage.Error(SyncFailureReason.NETWORK), viewModel.uiState.value.pendingSyncMessage)
    }

    @Test
    fun `onSyncMessageShown clears the pending message`() = runTest {
        observeState()
        viewModel.syncNow()

        viewModel.onSyncMessageShown()

        assertNull(viewModel.uiState.value.pendingSyncMessage)
    }
}

/** Replays whatever the test pushes into [preferences] and records writes. */
private class FakeUserPreferencesRepository : UserPreferencesRepository {

    override val preferences = MutableStateFlow(UserPreferences.Defaults)

    override suspend fun setPalette(palette: AppPalette) {
        preferences.value = preferences.value.copy(palette = palette)
    }

    override suspend fun setThemeMode(themeMode: ThemeMode) {
        preferences.value = preferences.value.copy(themeMode = themeMode)
    }

    override suspend fun toggleFavorite(restaurantId: Long) {
        val current = preferences.value.favoriteIds
        preferences.value = preferences.value.copy(
            favoriteIds = if (restaurantId in current) current - restaurantId else current + restaurantId
        )
    }
}

/** Never touches the network: records the last requested sync and replays a canned result. */
private class FakeDatabaseSyncManager(
    var result: DatabaseSyncResult = DatabaseSyncResult.Success(0)
) : DatabaseSyncManager {
    override suspend fun sync(): DatabaseSyncResult = result
}
