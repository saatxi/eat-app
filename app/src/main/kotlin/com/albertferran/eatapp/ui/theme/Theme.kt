package com.albertferran.eatapp.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Terracotta40,
    onPrimary = Color.White,
    primaryContainer = Terracotta80,
    onPrimaryContainer = Terracotta40,
    secondary = Sage40,
    onSecondary = Color.White,
    secondaryContainer = Sage80,
    onSecondaryContainer = Sage40,
    tertiary = Cream40,
    onTertiary = Color.White,
    tertiaryContainer = Cream80,
    onTertiaryContainer = Cream40,
    background = Neutral98,
    onBackground = Neutral10,
    surface = Neutral98,
    onSurface = Neutral10,
    surfaceVariant = NeutralVariant90,
    onSurfaceVariant = NeutralVariant30,
    outline = NeutralVariant50,
    outlineVariant = NeutralVariant80,
    surfaceDim = Neutral87,
    surfaceBright = Neutral98,
    surfaceContainerLowest = Neutral100,
    surfaceContainerLow = Neutral96,
    surfaceContainer = Neutral94,
    surfaceContainerHigh = Neutral92,
    surfaceContainerHighest = Neutral90,
    inverseSurface = Neutral20,
    inverseOnSurface = Neutral95,
    inversePrimary = Terracotta80,
    scrim = Color.Black,
    error = Error40,
    onError = Color.White,
    errorContainer = Error90,
    onErrorContainer = Error10
)

private val DarkColors = darkColorScheme(
    primary = Terracotta80,
    onPrimary = Terracotta40,
    primaryContainer = Terracotta40,
    onPrimaryContainer = Terracotta80,
    secondary = Sage80,
    onSecondary = Sage40,
    secondaryContainer = Sage40,
    onSecondaryContainer = Sage80,
    tertiary = Cream80,
    onTertiary = Cream40,
    tertiaryContainer = Cream40,
    onTertiaryContainer = Cream80,
    background = Neutral6,
    onBackground = Neutral90,
    surface = Neutral6,
    onSurface = Neutral90,
    surfaceVariant = NeutralVariant30,
    onSurfaceVariant = NeutralVariant80,
    outline = NeutralVariant60,
    outlineVariant = NeutralVariant30,
    surfaceDim = Neutral6,
    surfaceBright = Neutral24,
    surfaceContainerLowest = Neutral4,
    surfaceContainerLow = Neutral10,
    surfaceContainer = Neutral12,
    surfaceContainerHigh = Neutral17,
    surfaceContainerHighest = Neutral22,
    inverseSurface = Neutral90,
    inverseOnSurface = Neutral20,
    inversePrimary = Terracotta40,
    scrim = Color.Black,
    error = Error80,
    onError = Error20,
    errorContainer = Error30,
    onErrorContainer = Error90
)

@Composable
fun EatAppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColors else LightColors

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        shapes = Shapes,
        content = content
    )
}
