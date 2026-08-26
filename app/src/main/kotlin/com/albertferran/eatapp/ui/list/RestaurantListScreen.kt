package com.albertferran.eatapp.ui.list

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.RestaurantMenu
import androidx.compose.material.icons.outlined.SearchOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.albertferran.eatapp.BuildConfig
import com.albertferran.eatapp.R
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.sync.SyncFailureReason
import com.albertferran.eatapp.ui.AppViewModelProvider
import com.albertferran.eatapp.ui.common.cuisineIcon
import com.albertferran.eatapp.ui.common.cuisineTint

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RestaurantListScreen(
    onOpenRestaurant: (Long) -> Unit,
    viewModel: RestaurantListViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    var showOverflowMenu by remember { mutableStateOf(false) }
    var showAboutDialog by remember { mutableStateOf(false) }

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
                    IconButton(onClick = { showOverflowMenu = true }) {
                        Icon(Icons.Default.MoreVert, contentDescription = stringResource(R.string.list_action_more))
                    }
                    DropdownMenu(
                        expanded = showOverflowMenu,
                        onDismissRequest = { showOverflowMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.list_action_about)) },
                            onClick = {
                                showOverflowMenu = false
                                showAboutDialog = true
                            }
                        )
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
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 4.dp),
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

            val hasActiveFilter = uiState.searchQuery.isNotBlank() || uiState.minRating != null

            PullToRefreshBox(
                isRefreshing = uiState.isSyncing,
                onRefresh = viewModel::syncNow,
                modifier = Modifier.weight(1f).fillMaxWidth()
            ) {
                if (uiState.restaurants.isEmpty()) {
                    if (hasActiveFilter) {
                        EmptyState(
                            icon = Icons.Outlined.SearchOff,
                            title = stringResource(R.string.list_empty_no_results_title),
                            body = stringResource(R.string.list_empty_no_results_body)
                        )
                    } else {
                        EmptyState(
                            icon = Icons.Outlined.RestaurantMenu,
                            title = stringResource(R.string.list_empty_first_sync_title),
                            body = stringResource(R.string.list_empty_first_sync_body),
                            actionLabel = stringResource(R.string.list_action_sync),
                            onAction = viewModel::syncNow,
                            actionEnabled = !uiState.isSyncing
                        )
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

    if (showAboutDialog) {
        AlertDialog(
            onDismissRequest = { showAboutDialog = false },
            confirmButton = {
                TextButton(onClick = { showAboutDialog = false }) {
                    Text(stringResource(R.string.action_ok))
                }
            },
            title = { Text(stringResource(R.string.app_name)) },
            text = {
                Text(
                    stringResource(
                        R.string.about_version_template,
                        BuildConfig.VERSION_NAME,
                        BuildConfig.VERSION_CODE
                    )
                )
            }
        )
    }
}

@Composable
private fun EmptyState(
    icon: ImageVector,
    title: String,
    body: String,
    actionLabel: String? = null,
    onAction: () -> Unit = {},
    actionEnabled: Boolean = true
) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
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

@Composable
private fun RestaurantRow(restaurant: Restaurant, onClick: () -> Unit) {
    Card(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            val tint = cuisineTint(restaurant.cuisineType)
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(tint.container),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    cuisineIcon(restaurant.cuisineType),
                    contentDescription = null,
                    tint = tint.onContainer,
                    modifier = Modifier.size(24.dp)
                )
            }

            Column(modifier = Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text(text = restaurant.name, style = MaterialTheme.typography.titleLarge)
                Text(
                    text = restaurant.cuisineType,
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
            }

            Column(horizontalAlignment = Alignment.End) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Default.Star,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(16.dp).padding(end = 4.dp)
                    )
                    Text(
                        text = stringResource(R.string.rating_format, restaurant.rating),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
                Surface(
                    shape = MaterialTheme.shapes.extraSmall,
                    color = MaterialTheme.colorScheme.tertiaryContainer,
                    modifier = Modifier.padding(top = 6.dp)
                ) {
                    Text(
                        text = "$".repeat(restaurant.priceRange),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onTertiaryContainer,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                    )
                }
            }
        }
    }
}
