package com.saatxi.eatapp.ui.common

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.saatxi.eatapp.R

/** Widest price-range tier the scale offers; see [priceRangeLabel]. */
const val MAX_PRICE_RANGE = 6

/**
 * Euro-band display text for a price-range level (1-6), empty for 0 ("not
 * set") or anything else out of range — shared by every screen that draws
 * [com.saatxi.eatapp.data.local.Restaurant.priceRange]/[com.saatxi.eatapp.data.local.Visit.priceRange]
 * so the band boundaries live in exactly one place (`strings.xml`'s
 * `price_range_1`-`price_range_6`).
 */
@Composable
fun priceRangeLabel(priceRange: Int): String = when (priceRange) {
    1 -> stringResource(R.string.price_range_1)
    2 -> stringResource(R.string.price_range_2)
    3 -> stringResource(R.string.price_range_3)
    4 -> stringResource(R.string.price_range_4)
    5 -> stringResource(R.string.price_range_5)
    6 -> stringResource(R.string.price_range_6)
    else -> ""
}

/**
 * Six tappable euro-band tiles, single-select: tapping the already-selected
 * tile clears it back to 0 ("not set") — shared by the restaurant edit form
 * ([Restaurant.priceRange][com.saatxi.eatapp.data.local.Restaurant.priceRange])
 * and the log-visit form ([Visit.priceRange][com.saatxi.eatapp.data.local.Visit.priceRange]),
 * both on the same 0-6 scale. Unlike the old "$"-tile picker, these bands
 * don't nest inside each other, so only one can be selected at a time.
 */
@Composable
fun PriceRangePicker(priceRange: Int, onPriceRangeChange: (Int) -> Unit, modifier: Modifier = Modifier) {
    FlowRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        (1..MAX_PRICE_RANGE).forEach { level ->
            val selected = level == priceRange
            Surface(
                onClick = { onPriceRangeChange(if (selected) 0 else level) },
                shape = MaterialTheme.shapes.small,
                color = if (selected) MaterialTheme.colorScheme.tertiaryContainer else MaterialTheme.colorScheme.surfaceVariant
            ) {
                Text(
                    text = priceRangeLabel(level),
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
