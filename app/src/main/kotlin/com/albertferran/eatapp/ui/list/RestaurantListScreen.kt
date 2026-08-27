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
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import android.content.Context
import androidx.compose.ui.platform.LocalContext
import com.albertferran.eatapp.BuildConfig
import com.albertferran.eatapp.R
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.sync.RestaurantDatabaseSyncManager
import com.albertferran.eatapp.data.sync.SyncFailureReason
import com.albertferran.eatapp.ui.AppViewModelProvider
import com.albertferran.eatapp.ui.common.cuisineIcon
import com.albertferran.eatapp.ui.common.cuisineLabel
import com.albertferran.eatapp.ui.common.cuisineTint

@Composable
private fun formatRelativeTime(timestampMs: Long): String {
    val diff = System.currentTimeMillis() - timestampMs
    return when {
        diff < 60_000 -> stringResource(R.string.relative_time_just_now)
        diff < 3_600_000 -> {
            val minutes = (diff / 60_000).toInt()
            pluralStringResource(R.plurals.relative_time_minutes_ago, minutes, minutes)
        }
        diff < 86_400_000 -> {
            val hours = (diff / 3_600_000).toInt()
            pluralStringResource(R.plurals.relative_time_hours_ago, hours, hours)
        }
        else -> {
            val days = (diff / 86_400_000).toInt()
            pluralStringResource(R.plurals.relative_time_days_ago, days, days)
        }
    }
}

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
            Column {
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
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            }
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            OutlinedTextField(
                value = uiState.searchQuery,
                onValueChange = viewModel::onSearchQueryChange,
                label = { Text(stringResource(R.string.list_search_placeholder)) },
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            )

            PullToRefreshBox(
                isRefreshing = uiState.isSyncing,
                onRefresh = viewModel::syncNow,
                modifier = Modifier.weight(1f).fillMaxWidth()
            ) {
                if (uiState.restaurants.isEmpty() && !uiState.hasActiveFilter) {
                    // Nothing has ever been synced: there are no filters to offer yet.
                    EmptyState(
                        icon = Icons.Outlined.RestaurantMenu,
                        title = stringResource(R.string.list_empty_first_sync_title),
                        body = stringResource(R.string.list_empty_first_sync_body),
                        actionLabel = stringResource(R.string.list_action_sync),
                        onAction = viewModel::syncNow,
                        actionEnabled = !uiState.isSyncing
                    )
                } else {
                    // The filter controls live inside the list so they scroll away
                    // instead of permanently eating vertical space — and so they stay
                    // reachable when a filter matches nothing, which is exactly when
                    // the user needs them most.
                    LazyColumn(
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        item(key = "filters") {
                            FilterSection(
                                minRating = uiState.minRating,
                                onMinRatingChange = viewModel::onMinRatingChange,
                                cuisineType = uiState.cuisineType,
                                availableCuisines = uiState.availableCuisines,
                                onCuisineChange = viewModel::onCuisineChange
                            )
                        }

                        if (uiState.restaurants.isEmpty()) {
                            item(key = "no-results") {
                                EmptyState(
                                    icon = Icons.Outlined.SearchOff,
                                    title = stringResource(R.string.list_empty_no_results_title),
                                    body = stringResource(R.string.list_empty_no_results_body),
                                    actionLabel = stringResource(R.string.list_action_clear_filters),
                                    onAction = viewModel::clearFilters,
                                    modifier = Modifier.fillParentMaxHeight(0.6f)
                                )
                            }
                        } else {
                            items(uiState.restaurants, key = { it.id }) { restaurant ->
                                RestaurantRow(restaurant = restaurant, onClick = { onOpenRestaurant(restaurant.id) })
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAboutDialog) {
        val context = LocalContext.current
        val lastSyncTime = RestaurantDatabaseSyncManager.getLastSyncTime(context)
        val lastSyncText = if (lastSyncTime > 0) {
            stringResource(R.string.about_last_synced, formatRelativeTime(lastSyncTime))
        } else {
            stringResource(R.string.about_last_synced_never)
        }

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
                    ) + "\n\n" + lastSyncText
                )
            }
        )
    }
}

@Composable
private fun FilterSection(
    minRating: Int?,
    onMinRatingChange: (Int?) -> Unit,
    cuisineType: String?,
    availableCuisines: List<String>,
    onCuisineChange: (String?) -> Unit
) {
    val chipColors = FilterChipDefaults.filterChipColors(
        containerColor = MaterialTheme.colorScheme.surfaceVariant,
        labelColor = MaterialTheme.colorScheme.onSurfaceVariant,
        selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
        selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
    )

    Column {
        Text(
            text = stringResource(R.string.list_filter_min_rating),
            style = MaterialTheme.typography.labelMedium
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

        // Only the cuisines actually present in the synced data are offered, so the
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

@Composable
private fun EmptyState(
    icon: ImageVector,
    title: String,
    body: String,
    modifier: Modifier = Modifier.fillMaxSize(),
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
                    text = cuisineLabel(restaurant.cuisineType),
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
                    shape = RoundedCornerShape(percent = 50),
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
