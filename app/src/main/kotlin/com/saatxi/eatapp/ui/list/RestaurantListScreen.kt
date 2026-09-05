package com.saatxi.eatapp.ui.list

import android.content.res.Configuration
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.RestaurantMenu
import androidx.compose.material.icons.outlined.SearchOff
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.AppViewModelProvider
import com.saatxi.eatapp.ui.common.DeleteConfirmDialog
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
    val context = LocalContext.current
    // Set by a row's swipe-to-delete gesture — see RestaurantRow's own
    // onDeleteRequest doc for why the row itself never deletes directly.
    var pendingDelete by remember { mutableStateOf<RestaurantUiModel?>(null) }

    pendingDelete?.let { restaurant ->
        DeleteConfirmDialog(
            onConfirm = {
                viewModel.onDeleteRestaurant(restaurant.id)
                pendingDelete = null
            },
            onDismiss = { pendingDelete = null }
        )
    }

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
            SearchAndFilterBar(
                searchQuery = uiState.searchQuery,
                onSearchQueryChange = viewModel::onSearchQueryChange,
                // Same condition the list content below switches its empty state
                // on: nothing to sort or filter yet during the first load, or
                // before any restaurant has ever been added.
                showSortAndFilters = !uiState.isInitialLoad && (uiState.restaurants.isNotEmpty() || uiState.hasActiveFilter),
                sort = uiState.sort,
                onSortChange = viewModel::onSortChange,
                minRating = uiState.minRating,
                onMinRatingChange = viewModel::onMinRatingChange,
                cuisineType = uiState.cuisineType,
                availableCuisines = uiState.availableCuisines,
                onCuisineChange = viewModel::onCuisineChange,
                visited = uiState.visited,
                onVisitedChange = viewModel::onVisitedChange
            )

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
                                    onDeleteRequest = { pendingDelete = restaurant },
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
