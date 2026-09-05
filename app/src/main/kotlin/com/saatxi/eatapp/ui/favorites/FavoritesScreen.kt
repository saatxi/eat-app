package com.saatxi.eatapp.ui.favorites

import android.content.res.Configuration
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.SearchOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.AppViewModelProvider
import com.saatxi.eatapp.ui.list.EmptyState
import com.saatxi.eatapp.ui.list.RestaurantRow
import com.saatxi.eatapp.ui.list.SearchAndFilterBar
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import com.saatxi.eatapp.ui.theme.EatAppTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FavoritesScreen(
    onOpenRestaurant: (Long) -> Unit,
    viewModel: FavoritesViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            Column {
                TopAppBar(title = { Text(stringResource(R.string.favorites_title)) })
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            }
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            SearchAndFilterBar(
                searchQuery = uiState.searchQuery,
                onSearchQueryChange = viewModel::onSearchQueryChange,
                // Same condition the list content below switches its empty state
                // on: nothing to sort or filter yet during the first load, or
                // before there is a single favourite to narrow down.
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
                    // Nothing to draw yet either way: avoids flashing the empty state
                    // for a frame before the favourites list has emitted.
                } else if (uiState.restaurants.isEmpty() && !uiState.hasActiveFilter) {
                    // No favourites at all yet: there is nothing to search or filter.
                    EmptyState(
                        icon = Icons.Outlined.FavoriteBorder,
                        title = stringResource(R.string.favorites_empty_title),
                        body = stringResource(R.string.favorites_empty_body),
                        modifier = Modifier.fillMaxSize()
                    )
                } else {
                    LazyColumn(
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        if (uiState.restaurants.isEmpty()) {
                            // At least one favourite exists, just none matching the
                            // current search/filter — the same "no matches" wording
                            // the main list uses for the equivalent case.
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

private val previewFavorite = RestaurantUiModel(
    id = 1,
    name = "Cal Ferran",
    cuisineKey = "mediterranean",
    address = "Plaça Santa Anna, Mataró",
    rating = 4,
    priceLabel = "$$",
    visited = true,
    website = null,
    instagram = null,
    isFavorite = true
)

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun FavoritesEmptyPreview() {
    EatAppTheme {
        Surface {
            EmptyState(
                icon = Icons.Outlined.FavoriteBorder,
                title = stringResource(R.string.favorites_empty_title),
                body = stringResource(R.string.favorites_empty_body),
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun FavoritesRowPreview() {
    EatAppTheme {
        Surface {
            RestaurantRow(restaurant = previewFavorite, onClick = {}, onFavoriteToggle = {})
        }
    }
}
