package com.albertferran.eatapp.ui.list

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.albertferran.eatapp.R
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.sync.SyncFailureReason
import com.albertferran.eatapp.ui.AppViewModelProvider

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RestaurantListScreen(
    onOpenRestaurant: (Long) -> Unit,
    viewModel: RestaurantListViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    val syncErrorNetwork = stringResource(R.string.list_sync_error_network)
    val syncErrorInvalid = stringResource(R.string.list_sync_error_invalid)
    val syncErrorUnknown = stringResource(R.string.list_sync_error_unknown)
    val syncSuccessTemplate = stringResource(R.string.list_sync_success)

    LaunchedEffect(Unit) {
        viewModel.syncEvents.collect { event ->
            val message = when (event) {
                is SyncEvent.Success -> String.format(syncSuccessTemplate, event.count)
                is SyncEvent.Error -> when (event.reason) {
                    SyncFailureReason.NETWORK -> syncErrorNetwork
                    SyncFailureReason.INVALID_FILE -> syncErrorInvalid
                    SyncFailureReason.IO_ERROR, SyncFailureReason.UNKNOWN -> syncErrorUnknown
                }
            }
            snackbarHostState.showSnackbar(message)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.list_title)) },
                actions = {
                    if (uiState.isSyncing) {
                        CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    } else {
                        IconButton(onClick = viewModel::syncNow) {
                            Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.list_action_sync))
                        }
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            OutlinedTextField(
                value = uiState.searchQuery,
                onValueChange = viewModel::onSearchQueryChange,
                label = { Text(stringResource(R.string.list_search_placeholder)) },
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            )

            Text(
                text = stringResource(R.string.list_filter_min_rating),
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                (1..5).forEach { rating ->
                    FilterChip(
                        selected = uiState.minRating == rating,
                        onClick = {
                            viewModel.onMinRatingChange(if (uiState.minRating == rating) null else rating)
                        },
                        label = { Text("$rating+") }
                    )
                }
            }

            if (uiState.restaurants.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(stringResource(R.string.list_empty))
                }
            } else {
                LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(uiState.restaurants, key = { it.id }) { restaurant ->
                        RestaurantRow(restaurant = restaurant, onClick = { onOpenRestaurant(restaurant.id) })
                    }
                }
            }
        }
    }
}

@Composable
private fun RestaurantRow(restaurant: Restaurant, onClick: () -> Unit) {
    Card(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = restaurant.name, style = MaterialTheme.typography.titleLarge)
            Text(text = restaurant.cuisineType, style = MaterialTheme.typography.bodyLarge)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Star, contentDescription = null, modifier = Modifier.padding(end = 4.dp))
                Text(text = "${restaurant.rating}/5")
            }
        }
    }
}
