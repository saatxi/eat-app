package com.albertferran.eatapp.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

/**
 * The tone-to-role mapping, written once for every palette.
 *
 * This is the piece that used to be duplicated per scheme, and the reason the
 * old palette shipped a contrast bug: `onSecondaryContainer` was hand-wired to
 * tone 40 over a tone 80 container. Here the rule is stated once — an
 * on-container is always the far end of its own ramp — so a new palette cannot
 * reintroduce it. `ColorSchemeContrastTest` holds the line.
 */

fun PaletteTones.lightScheme(): ColorScheme = lightColorScheme(
    primary = primary.t40,
    onPrimary = Color.White,
    primaryContainer = primary.t90,
    onPrimaryContainer = primary.t10,
    secondary = secondary.t40,
    onSecondary = Color.White,
    secondaryContainer = secondary.t90,
    onSecondaryContainer = secondary.t10,
    tertiary = tertiary.t40,
    onTertiary = Color.White,
    tertiaryContainer = tertiary.t90,
    onTertiaryContainer = tertiary.t10,
    background = neutral.t98,
    onBackground = neutral.t10,
    surface = neutral.t98,
    onSurface = neutral.t10,
    surfaceVariant = neutralVariant.t90,
    onSurfaceVariant = neutralVariant.t30,
    outline = neutralVariant.t50,
    outlineVariant = neutralVariant.t80,
    surfaceDim = neutral.t87,
    surfaceBright = neutral.t98,
    surfaceContainerLowest = neutral.t100,
    surfaceContainerLow = neutral.t96,
    surfaceContainer = neutral.t94,
    surfaceContainerHigh = neutral.t92,
    surfaceContainerHighest = neutral.t90,
    inverseSurface = neutral.t20,
    inverseOnSurface = neutral.t95,
    inversePrimary = primary.t80,
    scrim = Color.Black,
    error = Error40,
    onError = Color.White,
    errorContainer = Error90,
    onErrorContainer = Error10
)

fun PaletteTones.darkScheme(): ColorScheme = darkColorScheme(
    primary = primary.t80,
    onPrimary = primary.t20,
    primaryContainer = primary.t30,
    onPrimaryContainer = primary.t90,
    secondary = secondary.t80,
    onSecondary = secondary.t20,
    secondaryContainer = secondary.t30,
    onSecondaryContainer = secondary.t90,
    tertiary = tertiary.t80,
    onTertiary = tertiary.t20,
    tertiaryContainer = tertiary.t30,
    onTertiaryContainer = tertiary.t90,
    background = neutral.t6,
    onBackground = neutral.t90,
    surface = neutral.t6,
    onSurface = neutral.t90,
    surfaceVariant = neutralVariant.t30,
    onSurfaceVariant = neutralVariant.t80,
    outline = neutralVariant.t60,
    outlineVariant = neutralVariant.t30,
    surfaceDim = neutral.t6,
    surfaceBright = neutral.t24,
    surfaceContainerLowest = neutral.t4,
    surfaceContainerLow = neutral.t10,
    surfaceContainer = neutral.t12,
    surfaceContainerHigh = neutral.t17,
    surfaceContainerHighest = neutral.t22,
    inverseSurface = neutral.t90,
    inverseOnSurface = neutral.t20,
    inversePrimary = primary.t40,
    scrim = Color.Black,
    error = Error80,
    onError = Error20,
    errorContainer = Error30,
    onErrorContainer = Error90
)

/**
 * Accents follow the same shape as the container roles above: a light container
 * with a dark on-colour, inverted in dark mode. Keeping the two in step is what
 * lets a cuisine badge sit next to a `primaryContainer` chip without looking
 * like it came from a different design.
 */
fun PaletteTones.lightAccents(): CuisineAccents =
    CuisineAccents(accents.map { CuisineTint(container = it.t90, onContainer = it.t10) })

fun PaletteTones.darkAccents(): CuisineAccents =
    CuisineAccents(accents.map { CuisineTint(container = it.t30, onContainer = it.t90) })
