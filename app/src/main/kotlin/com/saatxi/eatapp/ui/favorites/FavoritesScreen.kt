package com.saatxi.eatapp.ui.favorites

import android.content.res.Configuration
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.FavoriteBorder
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.AppViewModelProvider
import com.saatxi.eatapp.ui.list.EmptyState
import com.saatxi.eatapp.ui.list.RestaurantRow
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
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (uiState.isInitialLoad) {
                // Nothing to draw yet either way: avoids flashing the empty state
                // for a frame before the favourites list has emitted.
            } else if (uiState.restaurants.isEmpty()) {
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
