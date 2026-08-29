package com.saatxi.eatapp.data.prefs

import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import com.saatxi.eatapp.ui.settings.AppLanguage

/**
 * Reads and changes the language the app is actually displaying in, as
 * opposed to a value the app stores itself: `AppCompatDelegate` already
 * persists the chosen locales (and reapplies them on the next launch,
 * before `Application.onCreate` even runs) and, from API 33, delegates to
 * the system's own per-app language setting. Keeping a second, separately
 * persisted copy in `UserPreferencesRepository` would risk drifting from
 * whatever the user last set — including via Android's own Settings app.
 */
interface AppLocaleManager {
    fun getLanguage(): AppLanguage
    fun setLanguage(language: AppLanguage)
}

class AppCompatLocaleManager : AppLocaleManager {

    override fun getLanguage(): AppLanguage {
        val explicitTag = AppCompatDelegate.getApplicationLocales().toLanguageTags()
            .substringBefore(',')
            .takeIf { it.isNotEmpty() }
        // AppLanguage has no "follow the system" entry, but the app itself still
        // does until the user picks one: before that first pick, no per-app
        // override is set, so fall back to whichever supported language the
        // device's own locale resolves to, keeping the picker's initial
        // selection consistent with what is actually on screen.
        val tag = explicitTag ?: LocaleListCompat.getAdjustedDefault()[0]?.language
        return AppLanguage.entries.firstOrNull { it.tag == tag } ?: AppLanguage.Default
    }

    override fun setLanguage(language: AppLanguage) {
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(language.tag))
    }
}
