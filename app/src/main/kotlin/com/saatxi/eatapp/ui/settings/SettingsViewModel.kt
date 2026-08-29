package com.saatxi.eatapp.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.prefs.AppLocaleManager
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.sync.DatabaseSyncManager
import com.saatxi.eatapp.data.sync.DatabaseSyncResult
import com.saatxi.eatapp.ui.list.SyncMessage
import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.ThemeMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class SettingsUiState(
    val palette: AppPalette = AppPalette.Default,
    val themeMode: ThemeMode = ThemeMode.Default,
    val language: AppLanguage = AppLanguage.Default,
    val isSyncing: Boolean = false,
    val pendingSyncMessage: SyncMessage? = null
)

class SettingsViewModel(
    private val preferencesRepository: UserPreferencesRepository,
    private val syncManager: DatabaseSyncManager,
    private val localeManager: AppLocaleManager
) : ViewModel() {

    private val isSyncing = MutableStateFlow(false)
    private val pendingSyncMessage = MutableStateFlow<SyncMessage?>(null)

    // AppLocaleManager has no Flow of its own (see its kdoc): this only ever
    // changes through onLanguageChange below, so updating it there keeps this
    // in sync without needing to poll or observe anything external.
    private val language = MutableStateFlow(localeManager.getLanguage())

    val uiState: StateFlow<SettingsUiState> = combine(
        preferencesRepository.preferences,
        isSyncing,
        pendingSyncMessage,
        language
    ) { preferences, syncing, syncMessage, language ->
        SettingsUiState(
            palette = preferences.palette,
            themeMode = preferences.themeMode,
            language = language,
            isSyncing = syncing,
            pendingSyncMessage = syncMessage
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = SettingsUiState()
    )

    fun onPaletteChange(palette: AppPalette) {
        viewModelScope.launch { preferencesRepository.setPalette(palette) }
    }

    fun onThemeModeChange(themeMode: ThemeMode) {
        viewModelScope.launch { preferencesRepository.setThemeMode(themeMode) }
    }

    fun onLanguageChange(language: AppLanguage) {
        localeManager.setLanguage(language)
        this.language.value = language
    }

    fun syncNow() {
        if (isSyncing.value) return
        viewModelScope.launch {
            isSyncing.value = true
            val message = when (val result = syncManager.sync()) {
                is DatabaseSyncResult.Success -> SyncMessage.Success(result.importedCount)
                DatabaseSyncResult.UpToDate -> SyncMessage.UpToDate
                is DatabaseSyncResult.Failure -> SyncMessage.Error(result.reason)
            }
            isSyncing.value = false
            pendingSyncMessage.value = message
        }
    }

    /** Called once the screen has displayed the pending message, so it isn't shown again. */
    fun onSyncMessageShown() {
        pendingSyncMessage.value = null
    }
}
