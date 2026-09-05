package com.saatxi.eatapp.ui.list

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.IconToggleButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxState
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.common.RatingAndPriceRow
import com.saatxi.eatapp.ui.common.TagPillRow
import com.saatxi.eatapp.ui.common.cuisineBadgeTransition
import com.saatxi.eatapp.ui.common.cuisineIcon
import com.saatxi.eatapp.ui.common.cuisineLabel
import com.saatxi.eatapp.ui.common.cuisineTint
import com.saatxi.eatapp.ui.common.shimmerCircle
import com.saatxi.eatapp.ui.common.shimmerPlaceholder
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.theme.EatAppTheme

/** Internal rather than private: reused by [com.saatxi.eatapp.ui.favorites.FavoritesScreen]. */
@Composable
internal fun RestaurantRow(
    restaurant: RestaurantUiModel,
    onClick: () -> Unit,
    onFavoriteToggle: (Long) -> Unit,
    // Only ever requests a delete — the caller decides whether/how to confirm
    // (both screens show the same DeleteConfirmDialog) and only then actually
    // removes the row, so this row itself never has to know whether the
    // request was granted.
    onDeleteRequest: () -> Unit,
    modifier: Modifier = Modifier
) {
    // The row draws name, cuisine, address, rating and price as separate icons and
    // text nodes, which a screen reader would otherwise announce one fragment at a
    // time; clearAndSetSemantics collapses the whole card into one description
    // instead, while the card's own click action (added by Card's onClick, on the
    // same node) is untouched.
    val cuisineLabelText = cuisineLabel(restaurant.cuisineKey)
    val ratingDescription = stringResource(R.string.restaurant_rating_description, restaurant.rating)
    val priceDescription = restaurant.priceLabel.takeIf { it.isNotEmpty() }?.let {
        stringResource(R.string.restaurant_price_description, it.length)
    }
    val visitStatusText = stringResource(
        if (restaurant.visited) R.string.visit_status_visited else R.string.visit_status_want_to_try
    )
    val description = listOfNotNull(
        restaurant.name,
        cuisineLabelText,
        ratingDescription,
        priceDescription,
        restaurant.address,
        // Only worth announcing for the exception case; "visited" is the
        // default and every row already implies it by omission.
        visitStatusText.takeIf { !restaurant.visited }
    ).joinToString(", ")
    val haptic = LocalHapticFeedback.current
    val deleteActionLabel = stringResource(R.string.action_delete)

    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            when (value) {
                SwipeToDismissBoxValue.StartToEnd -> {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    onFavoriteToggle(restaurant.id)
                }
                SwipeToDismissBoxValue.EndToStart -> {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    onDeleteRequest()
                }
                SwipeToDismissBoxValue.Settled -> Unit
            }
            // Never let the swipe itself carry the row away: favouriting doesn't
            // remove anything, and a delete only actually happens once the
            // confirmation dialog the request above triggers is accepted — so
            // the row always springs back to Settled regardless of direction.
            false
        }
    )

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = { SwipeActionBackground(dismissState = dismissState, isFavorite = restaurant.isFavorite) },
        modifier = modifier.fillMaxWidth()
    ) {
        // The heart lives in a Box alongside the Card rather than inside it: the Card's
        // clearAndSetSemantics below collapses its whole subtree into one accessibility
        // node, which would swallow the heart's own toggle semantics and leave it
        // unreachable under TalkBack.
        Box(modifier = Modifier.fillMaxWidth()) {
            Card(
                onClick = onClick,
                modifier = Modifier
                    .fillMaxWidth()
                    .clearAndSetSemantics {
                        contentDescription = description
                        // Swiping to delete isn't discoverable through TalkBack's default
                        // gestures, so the same action is exposed here too — the only path
                        // onto this row that survives everything else being collapsed away.
                        customActions = listOf(CustomAccessibilityAction(deleteActionLabel) { onDeleteRequest(); true })
                    }
            ) {
                Row(
                    // Extra end padding reserves room for the heart overlaid in the Box
                    // below, so it doesn't sit on top of the rating/price column.
                    modifier = Modifier.padding(start = 12.dp, top = 12.dp, bottom = 12.dp, end = 44.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val tint = cuisineTint(restaurant.cuisineKey)
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            // The element the container transform into the detail screen runs on.
                            .cuisineBadgeTransition(restaurant.id)
                            .clip(CircleShape)
                            .background(tint.container),
                        contentAlignment = Alignment.Center
                    ) {
                        if (restaurant.photoPath != null) {
                            AsyncImage(
                                model = restaurant.photoPath,
                                contentDescription = null,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.fillMaxSize()
                            )
                        } else {
                            Icon(
                                cuisineIcon(restaurant.cuisineKey),
                                contentDescription = null,
                                tint = tint.onContainer,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                    }

                    Column(modifier = Modifier.weight(1f).padding(horizontal = 12.dp)) {
                        Text(text = restaurant.name, style = MaterialTheme.typography.titleLarge)
                        if (!restaurant.visited) {
                            Surface(
                                shape = RoundedCornerShape(percent = 50),
                                color = MaterialTheme.colorScheme.secondaryContainer,
                                modifier = Modifier.padding(top = 2.dp, bottom = 2.dp)
                            ) {
                                Text(
                                    text = stringResource(R.string.visit_status_want_to_try),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Text(
                            text = cuisineLabelText,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        restaurant.address?.let { address ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Outlined.LocationOn,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(16.dp).padding(end = 4.dp)
                                )
                                Text(
                                    text = address,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                        if (restaurant.tagsLabel.isNotEmpty()) {
                            TagPillRow(
                                tags = restaurant.tagsLabel.split(", "),
                                maxVisible = 3,
                                modifier = Modifier.padding(top = 4.dp)
                            )
                        }
                    }

                    RatingAndPriceRow(
                        rating = restaurant.rating,
                        priceLabel = restaurant.priceLabel,
                        starCount = 1,
                        starSize = 16.dp,
                        stacked = true
                    )
                }
            }

            IconToggleButton(
                checked = restaurant.isFavorite,
                onCheckedChange = {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    onFavoriteToggle(restaurant.id)
                },
                modifier = Modifier.align(Alignment.TopEnd)
            ) {
                Icon(
                    imageVector = if (restaurant.isFavorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                    contentDescription = stringResource(
                        if (restaurant.isFavorite) R.string.action_remove_favorite else R.string.action_add_favorite
                    ),
                    tint = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

/**
 * What's revealed behind [RestaurantRow] as it's dragged: a favourite-toggle
 * hint on the side swiped from (heart icon reflecting what the swipe would
 * actually do — offer to add if not yet favourited, remove if it already
 * is), a delete hint on the other. Nothing draws once the row has sprung
 * back to [SwipeToDismissBoxValue.Settled], so there's no flash of colour
 * behind a row that was only tapped, not swiped.
 */
@Composable
private fun SwipeActionBackground(dismissState: SwipeToDismissBoxState, isFavorite: Boolean) {
    val direction = dismissState.targetValue
    if (direction == SwipeToDismissBoxValue.Settled) return

    val isDelete = direction == SwipeToDismissBoxValue.EndToStart
    val containerColor = if (isDelete) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.primaryContainer
    val contentColor = if (isDelete) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.onPrimaryContainer
    val icon = when {
        isDelete -> Icons.Filled.Delete
        isFavorite -> Icons.Outlined.FavoriteBorder
        else -> Icons.Filled.Favorite
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(MaterialTheme.shapes.medium)
            .background(containerColor)
            .padding(horizontal = 20.dp),
        contentAlignment = if (isDelete) Alignment.CenterEnd else Alignment.CenterStart
    ) {
        // Decorative: it's a hint drawn behind a row mid-drag, not a target of
        // its own — the row's own contentDescription and the heart button's
        // still carry the real, tappable semantics.
        Icon(icon, contentDescription = null, tint = contentColor)
    }
}

/** How many skeleton rows fill the initial-load state — enough to fill a typical phone screen. */
internal const val SKELETON_ROW_COUNT = 6

/**
 * Stands in for [RestaurantRow] while the first load is still pending (F-67):
 * the same badge-plus-two-lines-plus-trailing-column shape, pulsing instead
 * of drawing real content, so the list reads as loading rather than empty.
 */
@Composable
internal fun RestaurantRowSkeleton() {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(modifier = Modifier.size(48.dp).shimmerCircle())

            Column(modifier = Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Box(modifier = Modifier.fillMaxWidth(0.55f).height(18.dp).shimmerPlaceholder())
                Box(modifier = Modifier.padding(top = 8.dp).fillMaxWidth(0.35f).height(14.dp).shimmerPlaceholder())
                Box(modifier = Modifier.padding(top = 8.dp).fillMaxWidth(0.7f).height(14.dp).shimmerPlaceholder())
            }

            Column(horizontalAlignment = Alignment.End) {
                Box(modifier = Modifier.width(44.dp).height(14.dp).shimmerPlaceholder())
                Box(modifier = Modifier.padding(top = 8.dp).width(28.dp).height(18.dp).shimmerPlaceholder())
            }
        }
    }
}

private val previewRestaurant = RestaurantUiModel(
    id = 1,
    name = "Cal Ferran",
    cuisineKey = "mediterranean",
    address = "Plaça Santa Anna, Mataró",
    rating = 4,
    priceLabel = "$$",
    visited = true,
    website = "https://calferran.example",
    instagram = "calferran",
    isFavorite = true
)

private val previewWantToTryRestaurant = previewRestaurant.copy(
    id = 2,
    name = "Ramen Ko",
    cuisineKey = "japanese",
    rating = 0,
    priceLabel = "",
    visited = false,
    isFavorite = false
)

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RestaurantRowSkeletonPreview() {
    EatAppTheme {
        Surface {
            RestaurantRowSkeleton()
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RestaurantRowPreview() {
    EatAppTheme {
        Surface {
            RestaurantRow(restaurant = previewRestaurant, onClick = {}, onFavoriteToggle = {}, onDeleteRequest = {})
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RestaurantRowWantToTryPreview() {
    EatAppTheme {
        Surface {
            RestaurantRow(restaurant = previewWantToTryRestaurant, onClick = {}, onFavoriteToggle = {}, onDeleteRequest = {})
        }
    }
}
