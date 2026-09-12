package com.saatxi.eatapp.ui.theme

import androidx.annotation.StringRes
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.theme.palette.GardenTones
import com.saatxi.eatapp.ui.theme.palette.IndigoTones
import com.saatxi.eatapp.ui.theme.palette.MercadoFrescoTones

/**
 * The palettes the user can pick between in Settings.
 *
 * The enum name is what gets persisted, so entries must not be renamed without
 * a migration; see `UserPreferencesRepository`. Renaming SAFFRON to
 * MERCADO_FRESCO is safe without one: `DataStoreUserPreferencesRepository`
 * looks the stored name up against `entries` and falls back to [Default] on a
 * miss, so a device with the old "SAFFRON" persisted just resolves to the new
 * default rather than crashing.
 */
enum class AppPalette(
    @StringRes val labelRes: Int,
    internal val tones: PaletteTones
) {
    MERCADO_FRESCO(R.string.palette_mercado_fresco, MercadoFrescoTones),
    GARDEN(R.string.palette_garden, GardenTones),
    INDIGO(R.string.palette_indigo, IndigoTones);

    companion object {
        val Default = MERCADO_FRESCO
    }
}

/** Light/dark override. */
enum class ThemeMode(@StringRes val labelRes: Int) {
    LIGHT(R.string.theme_mode_light),
    DARK(R.string.theme_mode_dark);

    companion object {
        val Default = LIGHT
    }
}

/**
 * Resolves [mode] to whether dark colors should be used. Shared rather than
 * inlined into [EatAppTheme] so a screen that needs to preview a palette (the
 * Settings picker) resolves this the same way the theme itself does, instead
 * of re-deriving it and risking drift.
 */
@Composable
fun isDarkTheme(mode: ThemeMode): Boolean = when (mode) {
    ThemeMode.LIGHT -> false
    ThemeMode.DARK -> true
}

@Composable
fun EatAppTheme(
    palette: AppPalette = AppPalette.Default,
    themeMode: ThemeMode = ThemeMode.Default,
    content: @Composable () -> Unit
) {
    val darkTheme = isDarkTheme(themeMode)

    // Assembling a scheme allocates ~50 Colors, so it is worth not redoing on
    // every recomposition — but only the two inputs can change it.
    val colorScheme = remember(palette, darkTheme) {
        if (darkTheme) palette.tones.darkScheme() else palette.tones.lightScheme()
    }
    val accents = remember(palette, darkTheme) {
        if (darkTheme) palette.tones.darkAccents() else palette.tones.lightAccents()
    }

    CompositionLocalProvider(LocalCuisineAccents provides accents) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = Typography,
            shapes = Shapes,
            content = content
        )
    }
}
