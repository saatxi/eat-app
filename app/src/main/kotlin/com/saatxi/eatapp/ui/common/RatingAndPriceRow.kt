package com.saatxi.eatapp.ui.common

import android.content.res.Configuration
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.theme.EatAppTheme
import com.saatxi.eatapp.ui.model.MAX_RATING

/**
 * The stars-plus-"N/5"-plus-price-pill markup that used to be hand-duplicated
 * across `RestaurantRow`, `RestaurantDetailScreen` and `RouletteResultCard`
 * (F-58) — pulled out once so a future tweak to the star tint logic or the
 * price pill's styling can no longer silently drift between the three.
 *
 * The three call sites don't draw quite the same *layout* — the list row
 * stacks a compact single-star line above the price pill to stay narrow,
 * while the detail and roulette screens lay a full five-star gauge and the
 * pill side by side — so [stacked] switches between those two shapes rather
 * than forcing one look on all three. [starCount] of 1 is what produces the
 * list row's "decorative accent star" look: with only one star, `index <
 * rating` isn't a meaningful gauge, so it always renders filled instead.
 *
 * [ratingContentDescription]/[priceContentDescription] are only non-null on
 * the detail screen, which isn't nested inside another element that already
 * collapses its semantics — the list row's card and the roulette result card
 * both merge this into a larger description elsewhere (or, for roulette,
 * don't yet — see F-58's note in the backlog).
 */
@Composable
internal fun RatingAndPriceRow(
    rating: Int,
    priceLabel: String,
    modifier: Modifier = Modifier,
    starCount: Int = MAX_RATING,
    starSize: Dp = 18.dp,
    showRatingLabel: Boolean = true,
    stacked: Boolean = false,
    horizontalArrangement: Arrangement.Horizontal = Arrangement.Start,
    pricePaddingHorizontal: Dp = 8.dp,
    pricePaddingVertical: Dp = 2.dp,
    ratingContentDescription: String? = null,
    priceContentDescription: String? = null
) {
    val stars: @Composable () -> Unit = {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = ratingContentDescription
                ?.let { description -> Modifier.clearAndSetSemantics { contentDescription = description } }
                ?: Modifier
        ) {
            repeat(starCount) { index ->
                Icon(
                    imageVector = Icons.Default.Star,
                    contentDescription = null,
                    // A single star is a decorative accent next to the number, not a
                    // gauge — it's always filled, regardless of the actual rating.
                    tint = if (starCount == 1 || index < rating) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.outlineVariant
                    },
                    modifier = Modifier.size(starSize)
                )
            }
            if (showRatingLabel) {
                Text(
                    text = stringResource(R.string.rating_format, rating),
                    style = MaterialTheme.typography.labelMedium,
                    color = if (starCount == 1) MaterialTheme.colorScheme.primary else Color.Unspecified,
                    modifier = Modifier.padding(start = if (starCount == 1) 4.dp else 6.dp)
                )
            }
        }
    }

    val price: @Composable () -> Unit = {
        // Absent rather than an empty pill when there's no price set yet.
        if (priceLabel.isNotEmpty()) {
            Surface(
                shape = RoundedCornerShape(percent = 50),
                color = MaterialTheme.colorScheme.tertiaryContainer,
                modifier = priceContentDescription
                    ?.let { description -> Modifier.clearAndSetSemantics { contentDescription = description } }
                    ?: Modifier
            ) {
                Text(
                    text = priceLabel,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onTertiaryContainer,
                    modifier = Modifier.padding(horizontal = pricePaddingHorizontal, vertical = pricePaddingVertical)
                )
            }
        }
    }

    if (stacked) {
        Column(modifier = modifier, horizontalAlignment = Alignment.End) {
            stars()
            Box(modifier = Modifier.padding(top = 6.dp)) { price() }
        }
    } else {
        Row(modifier = modifier, horizontalArrangement = horizontalArrangement, verticalAlignment = Alignment.CenterVertically) {
            stars()
            price()
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RatingAndPriceRowPreview() {
    EatAppTheme {
        Surface {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                // The list row's compact form.
                RatingAndPriceRow(rating = 4, priceLabel = "$$", starCount = 1, starSize = 16.dp, stacked = true)
                // The detail screen's form: full width, spread out.
                RatingAndPriceRow(
                    rating = 4,
                    priceLabel = "$$",
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    pricePaddingHorizontal = 10.dp,
                    pricePaddingVertical = 4.dp
                )
                // The roulette result card's form: stars only, no "N/5" label.
                RatingAndPriceRow(
                    rating = 4,
                    priceLabel = "$$",
                    starSize = 20.dp,
                    showRatingLabel = false,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                )
            }
        }
    }
}
