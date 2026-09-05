package com.saatxi.eatapp.ui.detail

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.AlternateEmail
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.RestaurantMenu
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.TopAppBarScrollBehavior
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import com.saatxi.eatapp.R
import com.saatxi.eatapp.data.local.instagramUrl
import com.saatxi.eatapp.data.share.RestaurantExport
import com.saatxi.eatapp.ui.AppViewModelProvider
import com.saatxi.eatapp.ui.common.cuisineBadgeTransition
import com.saatxi.eatapp.ui.common.cuisineIcon
import com.saatxi.eatapp.ui.common.cuisineLabel
import com.saatxi.eatapp.ui.common.cuisineTint
import com.saatxi.eatapp.ui.common.DeleteConfirmDialog
import com.saatxi.eatapp.ui.common.RatingAndPriceRow
import com.saatxi.eatapp.ui.common.TagPillRow
import com.saatxi.eatapp.ui.common.shareRestaurants
import com.saatxi.eatapp.ui.common.shimmerPlaceholder
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.theme.EatAppTheme

/** Size of the cuisine icon in the app bar, where the shared transition lands. */
private val CUISINE_BADGE_SIZE = 32.dp

@Composable
fun RestaurantDetailScreen(
    onBack: () -> Unit,
    onEditRestaurant: (Long) -> Unit,
    // Non-null only when hosted inside a list-detail pane (EatAppNavHost's
    // ListDetailPaneHost): there the id comes from the pane navigator, not
    // from a nav-backstack entry, so the default SavedStateHandle-backed
    // factory has nothing to read it from.
    restaurantId: Long? = null,
    viewModel: RestaurantDetailViewModel = viewModel(
        key = restaurantId?.let { "detail-$it" },
        factory = restaurantId?.let(AppViewModelProvider::detailViewModelFactory) ?: AppViewModelProvider.Factory
    )
) {
    val uiState by viewModel.uiState.collectAsState()
    RestaurantDetailContent(
        uiState = uiState,
        onBack = onBack,
        onFavoriteToggle = viewModel::onFavoriteToggle,
        onEdit = onEditRestaurant,
        onDelete = { viewModel.onDelete(onDeleted = onBack) }
    )
}

/**
 * The screen's actual content, taking [uiState] directly rather than collecting it
 * from a [RestaurantDetailViewModel] — that split is what lets this be previewed
 * with a hand-built state instead of a real ViewModel and its factory.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RestaurantDetailContent(
    uiState: DetailUiState,
    onBack: () -> Unit,
    onFavoriteToggle: () -> Unit = {},
    onEdit: (Long) -> Unit = {},
    onDelete: () -> Unit = {}
) {
    val context = LocalContext.current
    val scrollState = rememberScrollState()
    var showDeleteConfirm by remember { mutableStateOf(false) }
    // Guarded rather than the default `{ true }`: on a detail page short enough to
    // fit, an unguarded fling would still collapse the bar and leave a blank strip
    // under it, because there is no content to scroll up into the freed space.
    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(
        canScroll = { scrollState.canScrollForward || scrollState.canScrollBackward }
    )

    if (showDeleteConfirm) {
        DeleteConfirmDialog(
            onConfirm = {
                showDeleteConfirm = false
                onDelete()
            },
            onDismiss = { showDeleteConfirm = false }
        )
    }

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = {
            DetailTopBar(
                restaurant = (uiState as? DetailUiState.Loaded)?.restaurant,
                onBack = onBack,
                onFavoriteToggle = onFavoriteToggle,
                onEdit = onEdit,
                onDeleteRequest = { showDeleteConfirm = true },
                onShare = {
                    (uiState as? DetailUiState.Loaded)?.restaurant?.let { context.shareRestaurants(listOf(it.toExport())) }
                },
                scrollBehavior = scrollBehavior
            )
        }
    ) { padding ->
        when (val state = uiState) {
            DetailUiState.Loading -> {
                // Shape-matching skeleton cards (F-67) instead of a centred spinner —
                // reads as faster even though the actual wait is identical.
                RestaurantDetailSkeleton(modifier = Modifier.fillMaxSize().padding(padding))
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
                    current.photoPath?.let { photoPath ->
                        AsyncImage(
                            model = photoPath,
                            contentDescription = stringResource(R.string.detail_photo_description),
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(200.dp)
                                .clip(MaterialTheme.shapes.medium)
                        )
                    }

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
                            if (!current.visited) {
                                InfoRow(
                                    icon = Icons.Outlined.Schedule,
                                    text = stringResource(R.string.visit_status_want_to_try),
                                    topPadding = 10.dp
                                )
                            }
                            current.address?.let { address ->
                                InfoRow(
                                    icon = Icons.Outlined.LocationOn,
                                    text = address,
                                    topPadding = 10.dp,
                                    onClick = {
                                        context.openUri("geo:0,0?q=${Uri.encode(address)}")
                                    }
                                )
                            }
                            if (current.tagsLabel.isNotEmpty()) {
                                TagPillRow(
                                    tags = current.tagsLabel.split(", "),
                                    modifier = Modifier.padding(top = 10.dp)
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
                            // The star icons are decorative (contentDescription = null) and the
                            // "3/5" text next to them isn't natural speech, so each half of the
                            // row gets its own merged description instead of announcing as
                            // silent stars followed by "3 slash 5", or "$$" as "dollar dollar".
                            RatingAndPriceRow(
                                rating = current.rating,
                                priceLabel = current.priceLabel,
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                pricePaddingHorizontal = 10.dp,
                                pricePaddingVertical = 4.dp,
                                ratingContentDescription = stringResource(R.string.restaurant_rating_description, current.rating),
                                priceContentDescription = stringResource(R.string.restaurant_price_description, current.priceLabel.length)
                            )
                        }
                    }

                    current.notes?.let { notes ->
                        NotesCard(notes = notes)
                    }

                    if (current.hasLinks) {
                        LinksCard(
                            website = current.website,
                            instagram = current.instagram,
                            onOpen = { url -> context.openUri(url) }
                        )
                    }
                }
            }
        }
    }
}

/**
 * Stands in for the loaded screen's Overview and Rating-and-price cards while
 * the restaurant is still being fetched (F-67) — same two-card shape, pulsing
 * placeholders instead of real text, so the wait reads as loading rather than
 * as a blank page.
 */
@Composable
private fun RestaurantDetailSkeleton(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .padding(horizontal = 16.dp)
            .padding(top = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Box(modifier = Modifier.fillMaxWidth(0.4f).height(20.dp).shimmerPlaceholder())
                Box(modifier = Modifier.padding(top = 16.dp).fillMaxWidth(0.75f).height(16.dp).shimmerPlaceholder())
                Box(modifier = Modifier.padding(top = 10.dp).fillMaxWidth(0.55f).height(16.dp).shimmerPlaceholder())
            }
        }
        Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Box(modifier = Modifier.fillMaxWidth(0.35f).height(20.dp).shimmerPlaceholder())
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Box(modifier = Modifier.width(110.dp).height(18.dp).shimmerPlaceholder())
                    Box(modifier = Modifier.width(36.dp).height(20.dp).shimmerPlaceholder())
                }
            }
        }
    }
}

/** The user's own free-text note — drawn only when there is one. */
@Composable
private fun NotesCard(notes: String) {
    Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = stringResource(R.string.detail_section_notes),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(bottom = 12.dp)
            )
            Text(
                text = notes,
                style = MaterialTheme.typography.bodyLarge.copy(fontStyle = FontStyle.Italic)
            )
        }
    }
}

/**
 * Website and Instagram, drawn only when the synced data actually carries them
 * — the card is absent rather than empty for the rows that have neither.
 *
 * Both values were validated on import (`LinkValidation.kt`); the Instagram URL
 * is built here from a bare handle rather than stored, so there is no way for
 * the data file to choose the scheme.
 */
@Composable
private fun LinksCard(
    website: String?,
    instagram: String?,
    onOpen: (String) -> Unit
) {
    Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = stringResource(R.string.detail_section_links),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(bottom = 12.dp)
            )
            website?.let { url ->
                InfoRow(
                    icon = Icons.Outlined.Language,
                    // The scheme carries no meaning for the reader, and a long
                    // URL would wrap the row; the host is what identifies the site.
                    text = url.toUri().host ?: url,
                    onClick = { onOpen(url) }
                )
            }
            instagram?.let { handle ->
                InfoRow(
                    icon = Icons.Outlined.AlternateEmail,
                    text = stringResource(R.string.detail_link_handle_format, handle),
                    topPadding = if (website != null) 10.dp else 0.dp,
                    onClick = { onOpen(instagramUrl(handle)) }
                )
            }
        }
    }
}

/**
 * Hands a URI to whichever app claims it, and says so politely when none does.
 *
 * A device with no browser — or, for the address row, no maps app — must not
 * crash the detail screen, which is what an unguarded `startActivity` would do.
 *
 * The https Instagram URL deep-links into the Instagram app on its own when
 * that app is installed, which is why no `instagram://` scheme is needed here
 * and no `<queries>` entry in the manifest.
 */
/**
 * [RestaurantUiModel] only carries the formatted "$$" [RestaurantUiModel.priceLabel],
 * not the raw price range — its length recovers the original number, the same
 * trick the price content description already relies on above.
 */
private fun RestaurantUiModel.toExport() = RestaurantExport(
    name = name,
    cuisineType = cuisineKey,
    address = address,
    rating = rating,
    priceRange = priceLabel.length,
    visited = visited,
    website = website,
    instagram = instagram,
    notes = notes,
    tags = tagsLabel.split(", ").filter { it.isNotBlank() }
)

private fun Context.openUri(uri: String) {
    try {
        startActivity(Intent(Intent.ACTION_VIEW, uri.toUri()))
    } catch (e: ActivityNotFoundException) {
        Log.w("EatApp.Detail", "No activity can open $uri", e)
        Toast.makeText(this, R.string.detail_link_failed, Toast.LENGTH_SHORT).show()
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
    onFavoriteToggle: () -> Unit,
    onEdit: (Long) -> Unit,
    onDeleteRequest: () -> Unit,
    onShare: () -> Unit,
    scrollBehavior: TopAppBarScrollBehavior
) {
    val haptic = LocalHapticFeedback.current
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
            IconButton(
                onClick = {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    onFavoriteToggle()
                }
            ) {
                Icon(
                    imageVector = if (restaurant.isFavorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                    contentDescription = stringResource(
                        if (restaurant.isFavorite) R.string.action_remove_favorite else R.string.action_add_favorite
                    )
                )
            }
            IconButton(onClick = { onEdit(restaurant.id) }) {
                Icon(Icons.Filled.Edit, contentDescription = stringResource(R.string.detail_action_edit))
            }
            IconButton(onClick = onShare) {
                Icon(Icons.Filled.Share, contentDescription = stringResource(R.string.detail_action_share))
            }
            IconButton(onClick = onDeleteRequest) {
                Icon(Icons.Filled.Delete, contentDescription = stringResource(R.string.detail_action_delete))
            }
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
    isFavorite = true,
    notes = "Ask for the burrata to start. Book ahead on Fridays."
)

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RestaurantDetailScreenPreview() {
    EatAppTheme {
        RestaurantDetailContent(uiState = DetailUiState.Loaded(previewRestaurant), onBack = {})
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RestaurantDetailScreenLoadingPreview() {
    EatAppTheme {
        RestaurantDetailContent(uiState = DetailUiState.Loading, onBack = {})
    }
}
