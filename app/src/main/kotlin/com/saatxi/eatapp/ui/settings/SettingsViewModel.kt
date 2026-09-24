package com.saatxi.eatapp.ui.settings

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.saatxi.eatapp.data.prefs.AppLocaleManager
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.ui.common.shareRestaurants
import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.ThemeMode
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class SettingsUiState(
    val palette: AppPalette = AppPalette.Default,
    val themeMode: ThemeMode = ThemeMode.Default,
    val language: AppLanguage = AppLanguage.Default
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val preferencesRepository: UserPreferencesRepository,
    private val localeManager: AppLocaleManager,
    private val repository: RestaurantRepository
) : ViewModel() {

    // AppLocaleManager has no Flow of its own (see its kdoc): this only ever
    // changes through onLanguageChange below, so updating it there keeps this
    // in sync without needing to poll or observe anything external.
    private val language = MutableStateFlow(localeManager.getLanguage())

    val uiState: StateFlow<SettingsUiState> = combine(
        preferencesRepository.preferences,
        language
    ) { preferences, language ->
        SettingsUiState(
            palette = preferences.palette,
            themeMode = preferences.themeMode,
            language = language
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

    /**
     * Shares every restaurant — the same mechanism the list screen's "share
     * all" uses. [includeVisits] comes from the export-options dialog; when
     * false the file carries restaurants and tags only.
     */
    fun onExportData(context: Context, includeVisits: Boolean) {
        viewModelScope.launch {
            context.shareRestaurants(repository.exportRestaurants(includeVisits = includeVisits))
        }
    }

    /** Irreversible: wipes every restaurant. The screen confirms with the user before calling this. */
    fun onDeleteAllData() {
        viewModelScope.launch { repository.deleteAll() }
    }
}
