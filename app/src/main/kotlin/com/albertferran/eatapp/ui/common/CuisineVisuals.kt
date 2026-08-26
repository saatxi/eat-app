package com.albertferran.eatapp.ui.common

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BakeryDining
import androidx.compose.material.icons.filled.Bento
import androidx.compose.material.icons.filled.BreakfastDining
import androidx.compose.material.icons.filled.BrunchDining
import androidx.compose.material.icons.filled.DinnerDining
import androidx.compose.material.icons.filled.Fastfood
import androidx.compose.material.icons.filled.Grass
import androidx.compose.material.icons.filled.Icecream
import androidx.compose.material.icons.filled.KebabDining
import androidx.compose.material.icons.filled.LocalBar
import androidx.compose.material.icons.filled.LocalCafe
import androidx.compose.material.icons.filled.LocalDining
import androidx.compose.material.icons.filled.LocalPizza
import androidx.compose.material.icons.filled.LunchDining
import androidx.compose.material.icons.filled.OutdoorGrill
import androidx.compose.material.icons.filled.RamenDining
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.RiceBowl
import androidx.compose.material.icons.filled.SetMeal
import androidx.compose.material.icons.filled.SoupKitchen
import androidx.compose.material.icons.filled.SportsBar
import androidx.compose.material.icons.filled.Tapas
import androidx.compose.material.icons.filled.WineBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import com.albertferran.eatapp.data.local.Cuisine

/**
 * Since restaurants have no real photo data, list/detail screens use a cuisine-derived
 * icon and tint in its place instead of an image.
 *
 * All three helpers take the raw `cuisineType` string straight off the entity and
 * degrade gracefully when it isn't a key this build knows: generic icon, neutral
 * tint, and the raw value as the label.
 */
fun cuisineIcon(cuisineType: String): ImageVector = when (Cuisine.fromKey(cuisineType)) {
    Cuisine.MEDITERRANEAN -> Icons.Filled.LocalDining
    Cuisine.SPANISH -> Icons.Filled.Tapas
    Cuisine.ITALIAN -> Icons.Filled.LocalPizza
    Cuisine.JAPANESE -> Icons.Filled.RamenDining
    Cuisine.CHINESE -> Icons.Filled.RiceBowl
    Cuisine.ASIAN -> Icons.Filled.Bento
    Cuisine.INDIAN -> Icons.Filled.SoupKitchen
    Cuisine.MIDDLE_EASTERN -> Icons.Filled.KebabDining
    Cuisine.AMERICAN -> Icons.Filled.LunchDining
    Cuisine.SEAFOOD -> Icons.Filled.SetMeal
    Cuisine.BAR -> Icons.Filled.LocalBar
    Cuisine.BEER_BAR -> Icons.Filled.SportsBar
    Cuisine.WINE_BAR -> Icons.Filled.WineBar
    Cuisine.CAFE -> Icons.Filled.LocalCafe
    Cuisine.BAKERY -> Icons.Filled.BakeryDining
    Cuisine.DESSERT -> Icons.Filled.Icecream
    Cuisine.BREAKFAST -> Icons.Filled.BreakfastDining
    Cuisine.BRUNCH -> Icons.Filled.BrunchDining
    Cuisine.GRILL -> Icons.Filled.OutdoorGrill
    Cuisine.FAST_FOOD -> Icons.Filled.Fastfood
    Cuisine.FINE_DINING -> Icons.Filled.DinnerDining
    Cuisine.VEGETARIAN -> Icons.Filled.Grass
    null -> Icons.Filled.Restaurant
}

/** Localized display label, falling back to the raw stored value. */
@Composable
fun cuisineLabel(cuisineType: String): String =
    Cuisine.fromKey(cuisineType)?.let { stringResource(it.labelRes) } ?: cuisineType

data class CuisineTint(val container: Color, val onContainer: Color)

@Composable
fun cuisineTint(cuisineType: String): CuisineTint {
    val colorScheme = MaterialTheme.colorScheme
    // Keyed off the enum ordinal rather than the string's hash: stable across
    // releases, and spread evenly over the three container roles instead of
    // landing arbitrarily.
    return when (Cuisine.fromKey(cuisineType)?.ordinal?.mod(3)) {
        0 -> CuisineTint(colorScheme.primaryContainer, colorScheme.onPrimaryContainer)
        1 -> CuisineTint(colorScheme.secondaryContainer, colorScheme.onSecondaryContainer)
        2 -> CuisineTint(colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer)
        else -> CuisineTint(colorScheme.surfaceVariant, colorScheme.onSurfaceVariant)
    }
}
