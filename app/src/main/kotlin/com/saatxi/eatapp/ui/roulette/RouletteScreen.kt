package com.saatxi.eatapp.ui.roulette

import android.content.res.Configuration
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Casino
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.AppViewModelProvider
import com.saatxi.eatapp.ui.common.cuisineIcon
import com.saatxi.eatapp.ui.common.cuisineLabel
import com.saatxi.eatapp.ui.common.cuisineTint
import com.saatxi.eatapp.ui.list.EmptyState
import com.saatxi.eatapp.ui.model.MAX_RATING
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.theme.EatAppTheme

/** How long the card takes to flip face-on when a new pick lands. */
private const val SPIN_DURATION_MS = 450

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RouletteScreen(
    onOpenRestaurant: (Long) -> Unit,
    viewModel: RouletteViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsState()
    val haptic = LocalHapticFeedback.current

    Scaffold(
        topBar = { TopAppBar(title = { Text(stringResource(R.string.roulette_title)) }) }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = stringResource(R.string.roulette_prompt),
                style = MaterialTheme.typography.titleMedium
            )

            RouletteFilters(
                minRating = uiState.minRating,
                onMinRatingChange = viewModel::onMinRatingChange,
                favoritesOnly = uiState.favoritesOnly,
                onFavoritesOnlyChange = viewModel::onFavoritesOnlyChange
            )

            Box(
                modifier = Modifier.weight(1f).fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                if (uiState.isInitialLoad) {
                    CircularProgressIndicator()
                } else if (uiState.isEmpty) {
                    EmptyState(
                        icon = Icons.Outlined.Casino,
                        title = stringResource(R.string.roulette_empty_title),
                        body = stringResource(R.string.roulette_empty_body),
                        modifier = Modifier.fillMaxSize()
                    )
                } else {
                    // A one-shot spin driven separately from AnimatedContent's own
                    // transition, so the wheel still "spins" even when chance picks
                    // the same restaurant twice in a row and the content itself
                    // doesn't change.
                    val rotation = remember { Animatable(0f) }
                    LaunchedEffect(uiState.pickCount) {
                        if (uiState.pickCount > 0) {
                            rotation.snapTo(0f)
                            rotation.animateTo(
                                targetValue = 360f,
                                animationSpec = tween(SPIN_DURATION_MS, easing = FastOutSlowInEasing)
                            )
                            // Distinct from the press feedback below: this one marks the
                            // card actually landing on its pick, once the flip settles.
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        }
                    }

                    AnimatedContent(
                        targetState = uiState.picked,
                        transitionSpec = {
                            (fadeIn(tween(220)) + scaleIn(initialScale = 0.9f, animationSpec = tween(220)))
                                .togetherWith(fadeOut(tween(120)))
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .graphicsLayer {
                                rotationY = rotation.value
                                cameraDistance = 12f * density
                            },
                        label = "roulette-pick"
                    ) { picked ->
                        if (picked == null) {
                            RoulettePrompt()
                        } else {
                            RouletteResultCard(restaurant = picked, onClick = { onOpenRestaurant(picked.id) })
                        }
                    }
                }
            }

            Button(
                onClick = {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    viewModel.pick()
                },
                enabled = uiState.candidates.isNotEmpty(),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = stringResource(
                        if (uiState.picked == null) R.string.roulette_action_pick else R.string.roulette_action_again
                    )
                )
            }
        }
    }
}

@Composable
private fun RouletteFilters(
    minRating: Int?,
    onMinRatingChange: (Int?) -> Unit,
    favoritesOnly: Boolean,
    onFavoritesOnlyChange: (Boolean) -> Unit
) {
    val chipColors = FilterChipDefaults.filterChipColors(
        containerColor = MaterialTheme.colorScheme.surfaceVariant,
        labelColor = MaterialTheme.colorScheme.onSurfaceVariant,
        selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
        selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Same "no 1+ chip" reasoning as the list screen's filter row: every
        // synced restaurant already has a rating of at least 1.
        (2..5).forEach { rating ->
            FilterChip(
                selected = minRating == rating,
                onClick = { onMinRatingChange(if (minRating == rating) null else rating) },
                label = { Text("$rating+") },
                colors = chipColors
            )
        }
        FilterChip(
            selected = favoritesOnly,
            onClick = { onFavoritesOnlyChange(!favoritesOnly) },
            label = { Text(stringResource(R.string.roulette_only_favorites)) },
            colors = chipColors
        )
    }
}

@Composable
private fun RoulettePrompt() {
    Icon(
        Icons.Outlined.Casino,
        contentDescription = null,
        modifier = Modifier.size(96.dp),
        tint = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
private fun RouletteResultCard(restaurant: RestaurantUiModel, onClick: () -> Unit) {
    val tint = cuisineTint(restaurant.cuisineKey)
    Card(
        onClick = onClick,
        shape = MaterialTheme.shapes.large,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth().padding(24.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(88.dp)
                    .clip(CircleShape)
                    .background(tint.container),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    cuisineIcon(restaurant.cuisineKey),
                    contentDescription = null,
                    tint = tint.onContainer,
                    modifier = Modifier.size(44.dp)
                )
            }
            Text(
                text = restaurant.name,
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.padding(top = 16.dp)
            )
            Text(
                text = cuisineLabel(restaurant.cuisineKey),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Row(modifier = Modifier.padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                repeat(MAX_RATING) { index ->
                    Icon(
                        Icons.Default.Star,
                        contentDescription = null,
                        tint = if (index < restaurant.rating) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.outlineVariant
                        },
                        modifier = Modifier.size(20.dp)
                    )
                }
                if (restaurant.priceLabel.isNotEmpty()) {
                    Surface(
                        shape = RoundedCornerShape(percent = 50),
                        color = MaterialTheme.colorScheme.tertiaryContainer,
                        modifier = Modifier.padding(start = 10.dp)
                    ) {
                        Text(
                            text = restaurant.priceLabel,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onTertiaryContainer,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                        )
                    }
                }
            }
            restaurant.address?.let { address ->
                Text(
                    text = address,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
        }
    }
}

private val previewPick = RestaurantUiModel(
    id = 1,
    name = "Cal Ferran",
    cuisineKey = "mediterranean",
    address = "Plaça Santa Anna, Mataró",
    rating = 4,
    priceLabel = "$$",
    website = null,
    instagram = null,
    isFavorite = false
)

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RouletteResultCardPreview() {
    EatAppTheme {
        Surface {
            RouletteResultCard(restaurant = previewPick, onClick = {})
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RoulettePromptPreview() {
    EatAppTheme {
        Surface {
            RoulettePrompt()
        }
    }
}
