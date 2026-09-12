package com.saatxi.eatapp.ui.common

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * Four tappable "$"-level tiles, 1-4, with 0 ("not set") reachable by tapping
 * the lowest selected level again to clear it — shared by the restaurant edit
 * form ([Restaurant.priceRange][com.saatxi.eatapp.data.local.Restaurant.priceRange])
 * and the log-visit form ([Visit.priceRange][com.saatxi.eatapp.data.local.Visit.priceRange]),
 * both on the same 0-4 scale.
 */
@Composable
fun PriceRangePicker(priceRange: Int, onPriceRangeChange: (Int) -> Unit, modifier: Modifier = Modifier) {
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        (1..4).forEach { level ->
            val selected = level <= priceRange
            Surface(
                onClick = { onPriceRangeChange(if (priceRange == level) level - 1 else level) },
                shape = MaterialTheme.shapes.small,
                color = if (selected) MaterialTheme.colorScheme.tertiaryContainer else MaterialTheme.colorScheme.surfaceVariant
            ) {
                Text(
                    text = "$".repeat(level),
                    style = MaterialTheme.typography.labelLarge,
                    color = if (selected) {
                        MaterialTheme.colorScheme.onTertiaryContainer
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
                )
            }
        }
    }
}
