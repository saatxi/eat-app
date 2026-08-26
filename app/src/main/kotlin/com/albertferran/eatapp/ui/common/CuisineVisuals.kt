package com.albertferran.eatapp.ui.common

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BakeryDining
import androidx.compose.material.icons.filled.LocalBar
import androidx.compose.material.icons.filled.LocalCafe
import androidx.compose.material.icons.filled.LocalPizza
import androidx.compose.material.icons.filled.LunchDining
import androidx.compose.material.icons.filled.RamenDining
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Since restaurants have no real photo data, list/detail screens use a cuisine-derived
 * icon and tint in its place instead of an image.
 */
fun cuisineIcon(cuisineType: String): ImageVector {
    val lower = cuisineType.lowercase()
    return when {
        lower.contains("pizza") || lower.contains("italian") -> Icons.Filled.LocalPizza
        lower.contains("sushi") || lower.contains("ramen") || lower.contains("japan") -> Icons.Filled.RamenDining
        lower.contains("cafe") || lower.contains("coffee") -> Icons.Filled.LocalCafe
        lower.contains("bar") || lower.contains("pub") -> Icons.Filled.LocalBar
        lower.contains("bakery") || lower.contains("dessert") -> Icons.Filled.BakeryDining
        lower.contains("burger") || lower.contains("american") -> Icons.Filled.LunchDining
        else -> Icons.Filled.Restaurant
    }
}

data class CuisineTint(val container: Color, val onContainer: Color)

@Composable
fun cuisineTint(cuisineType: String): CuisineTint {
    val colorScheme = MaterialTheme.colorScheme
    return when (cuisineType.hashCode().mod(3)) {
        0 -> CuisineTint(colorScheme.primaryContainer, colorScheme.onPrimaryContainer)
        1 -> CuisineTint(colorScheme.secondaryContainer, colorScheme.onSecondaryContainer)
        else -> CuisineTint(colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer)
    }
}
