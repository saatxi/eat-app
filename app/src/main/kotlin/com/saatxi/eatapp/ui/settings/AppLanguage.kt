package com.saatxi.eatapp.ui.settings

import androidx.annotation.StringRes
import com.saatxi.eatapp.R

/**
 * The languages the user can pick between in Settings. `tag` is the BCP 47
 * language tag handed to [androidx.appcompat.app.AppCompatDelegate].
 *
 * There is deliberately no "follow the device language" entry: the app
 * always pins one of these three. Before the user has picked one explicitly,
 * `AppLocaleManager` resolves the initial selection to whichever of these
 * the device's own language already matches, defaulting to [ENGLISH]
 * otherwise — see its kdoc.
 *
 * The enum name is not persisted anywhere (see `AppLocaleManager`), so unlike
 * `AppPalette`/`ThemeMode` it is safe to reorder or rename freely.
 */
enum class AppLanguage(val tag: String, @StringRes val labelRes: Int) {
    ENGLISH("en", R.string.language_english),
    SPANISH("es", R.string.language_spanish),
    CATALAN("ca", R.string.language_catalan);

    companion object {
        val Default = ENGLISH
    }
}
