package com.saatxi.eatapp.ui.list

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.RestaurantMenu
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.SearchOff
import androidx.compose.material3.Badge
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconToggleButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import android.content.res.Configuration
import androidx.compose.ui.platform.LocalContext
import coil3.compose.AsyncImage
import com.saatxi.eatapp.R
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.ui.AppViewModelProvider
import com.saatxi.eatapp.ui.common.cuisineBadgeTransition
import com.saatxi.eatapp.ui.common.cuisineIcon
import com.saatxi.eatapp.ui.common.cuisineLabel
import com.saatxi.eatapp.ui.common.cuisineTint
import com.saatxi.eatapp.ui.common.RatingAndPriceRow
import com.saatxi.eatapp.ui.common.TagPillRow
import com.saatxi.eatapp.ui.common.shimmerCircle
import com.saatxi.eatapp.ui.common.shimmerPlaceholder
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.theme.EatAppTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RestaurantListScreen(
    onOpenRestaurant: (Long) -> Unit,
    onAddRestaurant: () -> Unit,
    viewModel: RestaurantListViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsState()
    // Survives rotation but not process death on purpose: which filters are
    // active is what matters across a config change, not whether the row
    // happened to be open.
    var filtersExpanded by rememberSaveable { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current
    val context = LocalContext.current

    Scaffold(
        topBar = {
            Column {
                TopAppBar(
                    title = { Text(stringResource(R.string.list_title)) },
                    actions = {
                        IconButton(onClick = { viewModel.onShareAll(context) }) {
                            Icon(Icons.Default.Share, contentDescription = stringResource(R.string.list_action_share_all))
                        }
                    }
                )
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            }
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onAddRestaurant) {
                Icon(Icons.Default.Add, contentDescription = stringResource(R.string.list_action_add_restaurant))
            }
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            OutlinedTextField(
                value = uiState.searchQuery,
                onValueChange = viewModel::onSearchQueryChange,
                // A placeholder rather than a label: the label would float above the
                // text for good once the field has content, costing that height on
                // every screen for a field whose purpose the icon already states.
                placeholder = { Text(stringResource(R.string.list_search_placeholder)) },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                trailingIcon = {
                    if (uiState.searchQuery.isNotEmpty()) {
                        IconButton(onClick = { viewModel.onSearchQueryChange("") }) {
                            Icon(
                                Icons.Default.Close,
                                contentDescription = stringResource(R.string.list_search_clear)
                            )
                        }
                    }
                },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                // Results already follow every keystroke, so the Search key has
                // nothing left to submit — it just gets the keyboard out of the way.
                keyboardActions = KeyboardActions(onSearch = { focusManager.clearFocus() }),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            )

            // Same condition the list content below switches its empty state on:
            // nothing to sort or filter yet during the first load, or before any
            // restaurant has ever been added.
            if (!uiState.isInitialLoad && (uiState.restaurants.isNotEmpty() || uiState.hasActiveFilter)) {
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                    RestaurantSort.entries.forEachIndexed { index, option ->
                        // The full "Rating (highest first)"-style wording is what
                        // sortLabel() returns, meant for a dropdown with room to
                        // spare; a two-way segmented row splits a fixed width in
                        // half, so the visible text is the short form and the full
                        // one only reaches screen readers, via the button's own
                        // content description.
                        val fullLabel = sortLabel(option)
                        SegmentedButton(
                            selected = uiState.sort == option,
                            onClick = { viewModel.onSortChange(option) },
                            shape = SegmentedButtonDefaults.itemShape(index = index, count = RestaurantSort.entries.size),
                            modifier = Modifier.semantics { contentDescription = fullLabel },
                            // The default checkmark eats into the half-width share this
                            // row is already tight on (see the comment above) and clips a
                            // longer translation (e.g. Spanish "Puntuación") — the fill
                            // colour already marks the selection.
                            icon = {}
                        ) {
                            Text(sortLabelShort(option))
                        }
                    }
                }

                val activeFilterCount = (if (uiState.minRating != null) 1 else 0) +
                    (if (uiState.cuisineType != null) 1 else 0) +
                    (if (uiState.visited != null) 1 else 0)
                val chevronRotation by animateFloatAsState(
                    targetValue = if (filtersExpanded) 180f else 0f,
                    label = "filters-chevron"
                )
                val badgeCountDescription = pluralStringResource(
                    R.plurals.list_filters_active_count,
                    activeFilterCount,
                    activeFilterCount
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(
                            onClickLabel = stringResource(
                                if (filtersExpanded) R.string.list_filters_collapse else R.string.list_filters_expand
                            )
                        ) { filtersExpanded = !filtersExpanded }
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.FilterList, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        text = stringResource(R.string.list_filters_title),
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(start = 8.dp)
                    )
                    if (activeFilterCount > 0) {
                        Badge(
                            modifier = Modifier
                                .padding(start = 8.dp)
                                .semantics { contentDescription = badgeCountDescription }
                        ) {
                            Text(activeFilterCount.toString())
                        }
                    }
                    Box(modifier = Modifier.weight(1f))
                    Icon(
                        Icons.Default.ExpandMore,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.graphicsLayer { rotationZ = chevronRotation }
                    )
                }
                AnimatedVisibility(visible = filtersExpanded) {
                    FilterSection(
                        minRating = uiState.minRating,
                        onMinRatingChange = viewModel::onMinRatingChange,
                        cuisineType = uiState.cuisineType,
                        availableCuisines = uiState.availableCuisines,
                        onCuisineChange = viewModel::onCuisineChange,
                        visited = uiState.visited,
                        onVisitedChange = viewModel::onVisitedChange,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                    )
                }
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            }

            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                if (uiState.isInitialLoad) {
                    // The database has not emitted yet, so an empty list here means
                    // "not loaded", not "nothing to show" — painting the empty state
                    // would flash it for a frame on every cold start. Shape-matching
                    // skeleton rows (F-67) read as faster than a centred spinner even
                    // though the actual wait is identical.
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        repeat(SKELETON_ROW_COUNT) { RestaurantRowSkeleton() }
                    }
                } else if (uiState.restaurants.isEmpty() && !uiState.hasActiveFilter) {
                    // Nothing has ever been added: there are no filters to offer yet.
                    EmptyState(
                        icon = Icons.Outlined.RestaurantMenu,
                        title = stringResource(R.string.list_empty_title),
                        body = stringResource(R.string.list_empty_body),
                        modifier = Modifier.fillMaxSize(),
                        actionLabel = stringResource(R.string.list_action_add_restaurant),
                        onAction = onAddRestaurant
                    )
                } else {
                    LazyColumn(
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        if (uiState.restaurants.isEmpty()) {
                            item(key = "no-results", contentType = "empty") {
                                EmptyState(
                                    icon = Icons.Outlined.SearchOff,
                                    title = stringResource(R.string.list_empty_no_results_title),
                                    body = stringResource(R.string.list_empty_no_results_body),
                                    actionLabel = stringResource(R.string.list_action_clear_filters),
                                    onAction = viewModel::clearFilters,
                                    modifier = Modifier.fillParentMaxHeight(0.6f).animateItem()
                                )
                            }
                        } else {
                            // Most useful precisely when a filter has narrowed the list down —
                            // an unfiltered count adds nothing you can't already see. When
                            // browsing everything instead (F-66), that same spot offers a
                            // starting point rather than sitting blank.
                            if (uiState.hasActiveFilter) {
                                item(key = "result-count", contentType = "header") {
                                    Text(
                                        text = pluralStringResource(
                                            R.plurals.list_result_count,
                                            uiState.restaurants.size,
                                            uiState.restaurants.size
                                        ),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.animateItem()
                                    )
                                }
                            } else {
                                item(key = "suggestions", contentType = "header") {
                                    val topCuisine = remember(uiState.restaurants) {
                                        uiState.restaurants.groupingBy { it.cuisineKey }.eachCount().maxByOrNull { it.value }?.key
                                    }
                                    SearchSuggestionsRow(
                                        topCuisine = topCuisine,
                                        onMinRatingChange = viewModel::onMinRatingChange,
                                        onVisitedChange = viewModel::onVisitedChange,
                                        onCuisineChange = viewModel::onCuisineChange,
                                        modifier = Modifier.animateItem()
                                    )
                                }
                            }
                            items(uiState.restaurants, key = { it.id }, contentType = { "restaurant" }) { restaurant ->
                                RestaurantRow(
                                    restaurant = restaurant,
                                    onClick = { onOpenRestaurant(restaurant.id) },
                                    onFavoriteToggle = viewModel::onFavoriteToggle,
                                    modifier = Modifier.animateItem()
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun sortLabel(sort: RestaurantSort): String = when (sort) {
    RestaurantSort.NAME -> stringResource(R.string.list_sort_name)
    RestaurantSort.RATING -> stringResource(R.string.list_sort_rating)
}

@Composable
private fun sortLabelShort(sort: RestaurantSort): String = when (sort) {
    RestaurantSort.NAME -> stringResource(R.string.list_sort_name_short)
    RestaurantSort.RATING -> stringResource(R.string.list_sort_rating_short)
}

@Composable
private fun FilterSection(
    minRating: Int?,
    onMinRatingChange: (Int?) -> Unit,
    cuisineType: String?,
    availableCuisines: List<String>,
    onCuisineChange: (String?) -> Unit,
    visited: Boolean?,
    onVisitedChange: (Boolean?) -> Unit,
    modifier: Modifier = Modifier
) {
    val chipColors = FilterChipDefaults.filterChipColors(
        containerColor = MaterialTheme.colorScheme.surfaceVariant,
        labelColor = MaterialTheme.colorScheme.onSurfaceVariant,
        selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
        selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
    )

    Column(modifier = modifier) {
        Text(
            text = stringResource(R.string.list_filter_visit_status),
            style = MaterialTheme.typography.labelMedium
        )
        Row(
            modifier = Modifier.padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = visited == false,
                onClick = { onVisitedChange(if (visited == false) null else false) },
                label = { Text(stringResource(R.string.visit_status_want_to_try)) },
                colors = chipColors
            )
            FilterChip(
                selected = visited == true,
                onClick = { onVisitedChange(if (visited == true) null else true) },
                label = { Text(stringResource(R.string.visit_status_visited)) },
                colors = chipColors
            )
        }

        Text(
            text = stringResource(R.string.list_filter_min_rating),
            style = MaterialTheme.typography.labelMedium,
            modifier = Modifier.padding(top = 8.dp)
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            (1..5).forEach { rating ->
                FilterChip(
                    selected = minRating == rating,
                    onClick = { onMinRatingChange(if (minRating == rating) null else rating) },
                    label = { Text("$rating+") },
                    colors = chipColors
                )
            }
        }

        // Only the cuisines actually present in the data are offered, so the
        // row stays short instead of listing all 24 vocabulary entries.
        if (availableCuisines.isNotEmpty()) {
            val sortedCuisines = availableCuisines
                .map { key -> key to cuisineLabel(key) }
                .sortedBy { (_, label) -> label.lowercase() }

            Text(
                text = stringResource(R.string.list_filter_cuisine),
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.padding(top = 8.dp)
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                sortedCuisines.forEach { (key, label) ->
                    FilterChip(
                        selected = cuisineType == key,
                        onClick = { onCuisineChange(if (cuisineType == key) null else key) },
                        label = { Text(label) },
                        leadingIcon = {
                            Icon(
                                cuisineIcon(key),
                                contentDescription = null,
                                modifier = Modifier.size(FilterChipDefaults.IconSize)
                            )
                        },
                        colors = chipColors
                    )
                }
            }
        }
    }
}

/** What "top rated" means for the [SearchSuggestionsRow] shortcut — same threshold [FilterSection]'s own "4+" chip offers. */
private const val TOP_RATED_MIN_RATING = 4

/**
 * A starting point for browsing shown in place of the (otherwise blank)
 * space above the list once there's nothing to search or filter by yet
 * (F-66) — each chip is a shortcut into one of [FilterSection]'s own
 * filters, not a separate feature of its own. [topCuisine] is whichever key
 * appears most often in the restaurants currently on screen (null only when
 * there are none, in which case this composable isn't reached at all).
 */
@Composable
private fun SearchSuggestionsRow(
    topCuisine: String?,
    onMinRatingChange: (Int?) -> Unit,
    onVisitedChange: (Boolean?) -> Unit,
    onCuisineChange: (String?) -> Unit,
    modifier: Modifier = Modifier
) {
    val chipColors = FilterChipDefaults.filterChipColors(
        containerColor = MaterialTheme.colorScheme.surfaceVariant,
        labelColor = MaterialTheme.colorScheme.onSurfaceVariant
    )

    Column(modifier = modifier) {
        Text(
            text = stringResource(R.string.list_suggestions_title),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(top = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = false,
                onClick = { onMinRatingChange(TOP_RATED_MIN_RATING) },
                label = { Text(stringResource(R.string.list_suggestion_top_rated)) },
                leadingIcon = {
                    Icon(Icons.Default.Star, contentDescription = null, modifier = Modifier.size(FilterChipDefaults.IconSize))
                },
                colors = chipColors
            )
            FilterChip(
                selected = false,
                onClick = { onVisitedChange(false) },
                label = { Text(stringResource(R.string.visit_status_want_to_try)) },
                leadingIcon = {
                    Icon(Icons.Outlined.Schedule, contentDescription = null, modifier = Modifier.size(FilterChipDefaults.IconSize))
                },
                colors = chipColors
            )
            topCuisine?.let { cuisine ->
                FilterChip(
                    selected = false,
                    onClick = { onCuisineChange(cuisine) },
                    label = { Text(cuisineLabel(cuisine)) },
                    leadingIcon = {
                        Icon(cuisineIcon(cuisine), contentDescription = null, modifier = Modifier.size(FilterChipDefaults.IconSize))
                    },
                    colors = chipColors
                )
            }
        }
    }
}

/** Internal rather than private: reused by [com.saatxi.eatapp.ui.favorites.FavoritesScreen]. */
@Composable
internal fun EmptyState(
    icon: ImageVector,
    title: String,
    body: String,
    modifier: Modifier = Modifier,
    actionLabel: String? = null,
    onAction: () -> Unit = {},
    actionEnabled: Boolean = true
) {
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(32.dp)
        ) {
            Icon(
                icon,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(top = 16.dp)
            )
            Text(
                text = body,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp)
            )
            if (actionLabel != null) {
                Button(onClick = onAction, enabled = actionEnabled, modifier = Modifier.padding(top = 20.dp)) {
                    Text(actionLabel)
                }
            }
        }
    }
}

/** Internal rather than private: reused by [com.saatxi.eatapp.ui.favorites.FavoritesScreen]. */
@Composable
internal fun RestaurantRow(
    restaurant: RestaurantUiModel,
    onClick: () -> Unit,
    onFavoriteToggle: (Long) -> Unit,
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

    // The heart lives in a Box alongside the Card rather than inside it: the Card's
    // clearAndSetSemantics below collapses its whole subtree into one accessibility
    // node, which would swallow the heart's own toggle semantics and leave it
    // unreachable under TalkBack.
    Box(modifier = modifier.fillMaxWidth()) {
        Card(
            onClick = onClick,
            modifier = Modifier
                .fillMaxWidth()
                .clearAndSetSemantics { contentDescription = description }
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

/** How many skeleton rows fill the initial-load state — enough to fill a typical phone screen. */
private const val SKELETON_ROW_COUNT = 6

/**
 * Stands in for [RestaurantRow] while the first load is still pending (F-67):
 * the same badge-plus-two-lines-plus-trailing-column shape, pulsing instead
 * of drawing real content, so the list reads as loading rather than empty.
 */
@Composable
private fun RestaurantRowSkeleton() {
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
            RestaurantRow(restaurant = previewRestaurant, onClick = {}, onFavoriteToggle = {})
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RestaurantRowWantToTryPreview() {
    EatAppTheme {
        Surface {
            RestaurantRow(restaurant = previewWantToTryRestaurant, onClick = {}, onFavoriteToggle = {})
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun SearchSuggestionsRowPreview() {
    EatAppTheme {
        Surface {
            SearchSuggestionsRow(
                topCuisine = "japanese",
                onMinRatingChange = {},
                onVisitedChange = {},
                onCuisineChange = {},
                modifier = Modifier.padding(16.dp)
            )
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun EmptyStateFirstAddPreview() {
    EatAppTheme {
        Surface {
            EmptyState(
                icon = Icons.Outlined.RestaurantMenu,
                title = stringResource(R.string.list_empty_title),
                body = stringResource(R.string.list_empty_body),
                modifier = Modifier.fillMaxSize(),
                actionLabel = stringResource(R.string.list_action_add_restaurant),
                onAction = {}
            )
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun EmptyStateNoResultsPreview() {
    EatAppTheme {
        Surface {
            EmptyState(
                icon = Icons.Outlined.SearchOff,
                title = stringResource(R.string.list_empty_no_results_title),
                body = stringResource(R.string.list_empty_no_results_body),
                modifier = Modifier.fillMaxSize(),
                actionLabel = stringResource(R.string.list_action_clear_filters),
                onAction = {}
            )
        }
    }
}
