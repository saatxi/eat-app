package com.albertferran.eatapp.ui.theme

import androidx.annotation.StringRes
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import com.albertferran.eatapp.R
import com.albertferran.eatapp.ui.theme.palette.GardenTones
import com.albertferran.eatapp.ui.theme.palette.IndigoTones
import com.albertferran.eatapp.ui.theme.palette.SaffronTones

/**
 * The palettes the user can pick between in Settings.
 *
 * The enum name is what gets persisted, so entries must not be renamed without
 * a migration; see `UserPreferencesRepository`.
 */
enum class AppPalette(
    @StringRes val labelRes: Int,
    internal val tones: PaletteTones
) {
    SAFFRON(R.string.palette_saffron, SaffronTones),
    GARDEN(R.string.palette_garden, GardenTones),
    INDIGO(R.string.palette_indigo, IndigoTones);

    companion object {
        val Default = SAFFRON
    }
}

/** Light/dark override, or defer to the system. */
enum class ThemeMode(@StringRes val labelRes: Int) {
    SYSTEM(R.string.theme_mode_system),
    LIGHT(R.string.theme_mode_light),
    DARK(R.string.theme_mode_dark);

    companion object {
        val Default = SYSTEM
    }
}

@Composable
fun EatAppTheme(
    palette: AppPalette = AppPalette.Default,
    themeMode: ThemeMode = ThemeMode.Default,
    content: @Composable () -> Unit
) {
    val darkTheme = when (themeMode) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }

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
