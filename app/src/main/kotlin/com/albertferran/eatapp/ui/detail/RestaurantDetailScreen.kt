package com.albertferran.eatapp.ui.detail

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.RestaurantMenu
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.TopAppBarScrollBehavior
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.albertferran.eatapp.R
import com.albertferran.eatapp.ui.AppViewModelProvider
import com.albertferran.eatapp.ui.common.cuisineBadgeTransition
import com.albertferran.eatapp.ui.common.cuisineIcon
import com.albertferran.eatapp.ui.common.cuisineLabel
import com.albertferran.eatapp.ui.common.cuisineTint
import com.albertferran.eatapp.ui.model.RestaurantUiModel

/** Size of the cuisine icon in the app bar, where the shared transition lands. */
private val CUISINE_BADGE_SIZE = 32.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RestaurantDetailScreen(
    onBack: () -> Unit,
    viewModel: RestaurantDetailViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val scrollState = rememberScrollState()
    // Guarded rather than the default `{ true }`: on a detail page short enough to
    // fit, an unguarded fling would still collapse the bar and leave a blank strip
    // under it, because there is no content to scroll up into the freed space.
    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(
        canScroll = { scrollState.canScrollForward || scrollState.canScrollBackward }
    )

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = {
            DetailTopBar(
                restaurant = (uiState as? DetailUiState.Loaded)?.restaurant,
                onBack = onBack,
                scrollBehavior = scrollBehavior
            )
        }
    ) { padding ->
        when (val state = uiState) {
            DetailUiState.Loading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }

            DetailUiState.NotFound -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(32.dp)
                    ) {
                        Icon(
                            Icons.Outlined.RestaurantMenu,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = stringResource(R.string.detail_not_found_title),
                            style = MaterialTheme.typography.titleMedium,
                            modifier = Modifier.padding(top = 16.dp)
                        )
                        Text(
                            text = stringResource(R.string.detail_not_found_body),
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                        Button(onClick = onBack, modifier = Modifier.padding(top = 20.dp)) {
                            Text(stringResource(R.string.action_go_back))
                        }
                    }
                }
            }

            is DetailUiState.Loaded -> {
                val current = state.restaurant
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .verticalScroll(scrollState)
                        .padding(horizontal = 16.dp)
                        .padding(top = 16.dp, bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(
                                text = stringResource(R.string.detail_section_overview),
                                style = MaterialTheme.typography.titleMedium,
                                modifier = Modifier.padding(bottom = 12.dp)
                            )
                            InfoRow(
                                icon = cuisineIcon(current.cuisineKey),
                                text = cuisineLabel(current.cuisineKey)
                            )
                            current.address?.let { address ->
                                InfoRow(
                                    icon = Icons.Outlined.LocationOn,
                                    text = address,
                                    topPadding = 10.dp,
                                    onClick = {
                                        val intent = Intent(Intent.ACTION_VIEW).apply {
                                            data = Uri.parse("geo:0,0?q=${Uri.encode(address)}")
                                        }
                                        context.startActivity(intent)
                                    }
                                )
                            }
                        }
                    }

                    Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(
                                text = stringResource(R.string.detail_section_rating),
                                style = MaterialTheme.typography.titleMedium,
                                modifier = Modifier.padding(bottom = 12.dp)
                            )
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                val ratingDescription = stringResource(
                                    R.string.restaurant_rating_description,
                                    current.rating
                                )
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    // The star icons are decorative (contentDescription = null) and the
                                    // "3/5" text next to them isn't natural speech, so the row would
                                    // otherwise announce as silent stars followed by "3 slash 5".
                                    modifier = Modifier.clearAndSetSemantics {
                                        contentDescription = ratingDescription
                                    }
                                ) {
                                    current.stars.forEach { filled ->
                                        Icon(
                                            Icons.Default.Star,
                                            contentDescription = null,
                                            tint = if (filled) {
                                                MaterialTheme.colorScheme.primary
                                            } else {
                                                MaterialTheme.colorScheme.outlineVariant
                                            },
                                            modifier = Modifier.size(18.dp)
                                        )
                                    }
                                    Text(
                                        text = stringResource(R.string.rating_format, current.rating),
                                        style = MaterialTheme.typography.labelMedium,
                                        modifier = Modifier.padding(start = 6.dp)
                                    )
                                }
                                val priceDescription = stringResource(
                                    R.string.restaurant_price_description,
                                    current.priceLabel.length
                                )
                                Surface(
                                    shape = RoundedCornerShape(percent = 50),
                                    color = MaterialTheme.colorScheme.tertiaryContainer,
                                    // Otherwise "$$" is read out as "dollar dollar".
                                    modifier = Modifier.clearAndSetSemantics {
                                        contentDescription = priceDescription
                                    }
                                ) {
                                    Text(
                                        text = current.priceLabel,
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onTertiaryContainer,
                                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * The name lives in the app bar rather than in a hero block below it, so it stays on
 * screen — shrinking into the bar — however far the page is scrolled. The bar takes
 * over the cuisine tint the hero used to carry.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DetailTopBar(
    restaurant: RestaurantUiModel?,
    onBack: () -> Unit,
    scrollBehavior: TopAppBarScrollBehavior
) {
    val backButton: @Composable () -> Unit = {
        IconButton(onClick = onBack) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = stringResource(R.string.action_back)
            )
        }
    }

    if (restaurant == null) {
        // Loading and not-found have no name to put in a title, so they get a plain
        // bar rather than a large one standing empty above a centred message.
        TopAppBar(title = {}, navigationIcon = backButton)
        return
    }

    val tint = cuisineTint(restaurant.cuisineKey)
    LargeTopAppBar(
        title = {
            Text(
                text = restaurant.name,
                // The expanded bar has room for exactly one line of headlineMedium.
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        },
        navigationIcon = backButton,
        actions = {
            Icon(
                cuisineIcon(restaurant.cuisineKey),
                contentDescription = null,
                modifier = Modifier
                    .padding(end = 12.dp)
                    .size(CUISINE_BADGE_SIZE)
                    .cuisineBadgeTransition(restaurant.id)
            )
        },
        colors = TopAppBarDefaults.largeTopAppBarColors(
            // The same colour scrolled or not: the tint is this screen's identity, not
            // a scroll affordance, and fading it to the surface elevation colour would
            // drain the bar exactly as the title collapsed into it.
            containerColor = tint.container,
            scrolledContainerColor = tint.container,
            titleContentColor = tint.onContainer,
            navigationIconContentColor = tint.onContainer,
            actionIconContentColor = tint.onContainer
        ),
        scrollBehavior = scrollBehavior
    )
}

@Composable
private fun InfoRow(
    icon: ImageVector,
    text: String,
    topPadding: Dp = 0.dp,
    onClick: (() -> Unit)? = null
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .padding(top = topPadding)
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(18.dp).padding(end = 8.dp)
        )
        Text(text = text, style = MaterialTheme.typography.bodyLarge)
    }
}
