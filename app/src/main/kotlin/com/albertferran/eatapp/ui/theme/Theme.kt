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
    onTertiaryContainer = Cream40
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
    onTertiaryContainer = Cream80
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
