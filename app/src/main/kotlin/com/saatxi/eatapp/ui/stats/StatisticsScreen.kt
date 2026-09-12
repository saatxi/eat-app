package com.saatxi.eatapp.ui.stats

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material3.Card
import androidx.compose.material3.CardColors
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import com.saatxi.eatapp.R
import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.ui.common.cuisineIcon
import com.saatxi.eatapp.ui.common.cuisineLabel
import com.saatxi.eatapp.ui.common.cuisineTint
import com.saatxi.eatapp.ui.list.EmptyState
import com.saatxi.eatapp.ui.theme.EatAppTheme

@Composable
fun StatisticsScreen(
    onBack: () -> Unit,
    viewModel: StatisticsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    StatisticsContent(uiState = uiState, onBack = onBack)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StatisticsContent(uiState: StatisticsUiState, onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.stats_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.action_back))
                    }
                }
            )
        }
    ) { padding ->
        when {
            uiState.isInitialLoad -> {
                Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }

            uiState.totalCount == 0 -> {
                EmptyState(
                    icon = Icons.Outlined.BarChart,
                    title = stringResource(R.string.stats_empty_title),
                    body = stringResource(R.string.stats_empty_body),
                    modifier = Modifier.fillMaxSize().padding(padding)
                )
            }

            else -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .verticalScroll(rememberScrollState())
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // The total is promoted to its own headline tile (F-79) rather than one
                    // of four equal-weight tiles — it's the number that actually answers
                    // "how much have I collected", the other three just qualify it.
                    StatTile(
                        value = uiState.totalCount.toString(),
                        label = stringResource(R.string.stats_tile_total),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                        contentPadding = 20.dp,
                        valueStyle = MaterialTheme.typography.displaySmall,
                        valueColor = MaterialTheme.colorScheme.onPrimaryContainer,
                        labelStyle = MaterialTheme.typography.labelLarge,
                        labelColor = MaterialTheme.colorScheme.onPrimaryContainer,
                        labelTopPadding = 4.dp
                    )
                    // height(IntrinsicSize.Max) plus fillMaxHeight on each tile keeps the row
                    // level when one label wraps onto two lines and the others don't — on a
                    // narrow phone "Puntuació mitjana"/"Average rating" wraps while "Visitats"/
                    // "Visited" stays on one line, and without this the wrapped tile's card
                    // would grow taller than its neighbours instead of them all matching it.
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth().height(IntrinsicSize.Max)
                    ) {
                        StatTile(
                            value = uiState.visitedCount.toString(),
                            label = stringResource(R.string.stats_tile_visited),
                            modifier = Modifier.weight(1f).fillMaxHeight()
                        )
                        StatTile(
                            value = uiState.wantToTryCount.toString(),
                            label = stringResource(R.string.stats_tile_want_to_try),
                            modifier = Modifier.weight(1f).fillMaxHeight()
                        )
                        StatTile(
                            value = uiState.averageRating?.let { stringResource(R.string.stats_average_rating_value, it) }
                                ?: stringResource(R.string.stats_average_rating_none),
                            label = stringResource(R.string.stats_tile_average_rating),
                            modifier = Modifier.weight(1f).fillMaxHeight()
                        )
                    }

                    if (uiState.cuisineCounts.isNotEmpty()) {
                        val maxCount = uiState.cuisineCounts.maxOf { it.count }
                        StatsCard(title = stringResource(R.string.stats_section_cuisines)) {
                            uiState.cuisineCounts.forEach { cuisineCount ->
                                CuisineBarRow(cuisineCount = cuisineCount, maxCount = maxCount)
                            }
                        }
                    }

                    if (uiState.priceRangeCounts.isNotEmpty()) {
                        val maxCount = uiState.priceRangeCounts.maxOf { it.count }
                        StatsCard(title = stringResource(R.string.stats_section_price)) {
                            uiState.priceRangeCounts.sortedBy { it.priceRange }.forEach { priceRangeCount ->
                                PriceBarRow(priceRangeCount = priceRangeCount, maxCount = maxCount)
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * The headline total and the three smaller supporting stats (F-79) used to be
 * separate `HeadlineStatTile`/`SupportingStatTile` composables with identical
 * `Card > Column(center) > Text(value) + Text(label)` structure — every
 * difference between them (container color, padding, text styles) was already
 * a plain value, not a structural one, so they're one tile parameterized by
 * those values instead (F-85). Tabular numerals on the value keep its digits
 * from shifting width as the count changes.
 */
@Composable
private fun StatTile(
    value: String,
    label: String,
    modifier: Modifier = Modifier,
    colors: CardColors = CardDefaults.cardColors(),
    contentPadding: Dp = 12.dp,
    valueStyle: TextStyle = MaterialTheme.typography.titleLarge,
    valueColor: Color = Color.Unspecified,
    labelStyle: TextStyle = MaterialTheme.typography.labelSmall,
    labelColor: Color = MaterialTheme.colorScheme.onSurfaceVariant,
    labelTopPadding: Dp = 2.dp
) {
    Card(colors = colors, modifier = modifier.fillMaxWidth()) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            // Centered rather than top-aligned so a tile whose neighbour's longer
            // label wraps to a second line — stretching every tile in the row to
            // match it (see the supporting-stats Row's own comment) — doesn't leave
            // this one's shorter content pinned to the top with empty space below.
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.fillMaxWidth().fillMaxHeight().padding(contentPadding)
        ) {
            Text(text = value, style = valueStyle.copy(fontFeatureSettings = "tnum"), color = valueColor)
            Text(
                text = label,
                style = labelStyle,
                color = labelColor,
                modifier = Modifier.padding(top = labelTopPadding)
            )
        }
    }
}

/** Same title-then-content card shape the edit form's `EditSectionCard` and the detail screen's cards use. */
@Composable
private fun StatsCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(text = title, style = MaterialTheme.typography.titleMedium)
            content()
        }
    }
}

@Composable
private fun CuisineBarRow(cuisineCount: CuisineCount, maxCount: Int) {
    val tint = cuisineTint(cuisineCount.cuisineType)
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(tint.container),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                cuisineIcon(cuisineCount.cuisineType),
                contentDescription = null,
                tint = tint.onContainer,
                modifier = Modifier.size(18.dp)
            )
        }
        Column(modifier = Modifier.weight(1f).padding(start = 8.dp)) {
            Text(text = cuisineLabel(cuisineCount.cuisineType), style = MaterialTheme.typography.bodyMedium)
            // The count reads at the bar's own end (F-79) — the point of comparison —
            // rather than only in this header, which now carries the label alone.
            Row(modifier = Modifier.padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                StatBar(
                    fraction = cuisineCount.count.toFloat() / maxCount,
                    color = tint.onContainer,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    text = cuisineCount.count.toString(),
                    style = MaterialTheme.typography.labelMedium,
                    color = tint.onContainer,
                    modifier = Modifier.padding(start = 8.dp)
                )
            }
        }
    }
}

@Composable
private fun PriceBarRow(priceRangeCount: PriceRangeCount, maxCount: Int) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = if (priceRangeCount.priceRange == 0) {
                stringResource(R.string.stats_price_not_set)
            } else {
                "$".repeat(priceRangeCount.priceRange)
            },
            style = MaterialTheme.typography.labelMedium,
            modifier = Modifier.width(64.dp)
        )
        StatBar(
            fraction = priceRangeCount.count.toFloat() / maxCount,
            color = MaterialTheme.colorScheme.tertiary,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = priceRangeCount.count.toString(),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 8.dp)
        )
    }
}

/** A plain horizontal bar — no charting library needed for something this simple. */
@Composable
private fun StatBar(fraction: Float, color: Color, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(8.dp)
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(percent = 50))
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(fraction.coerceIn(0f, 1f))
                .fillMaxHeight()
                .background(color, RoundedCornerShape(percent = 50))
        )
    }
}

private val previewUiState = StatisticsUiState(
    totalCount = 12,
    visitedCount = 8,
    averageRating = 3.7,
    cuisineCounts = listOf(
        CuisineCount("japanese", 5),
        CuisineCount("mediterranean", 4),
        CuisineCount("seafood", 3)
    ),
    priceRangeCounts = listOf(
        PriceRangeCount(1, 3),
        PriceRangeCount(2, 6),
        PriceRangeCount(3, 2),
        PriceRangeCount(4, 1)
    ),
    isInitialLoad = false
)

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun StatisticsScreenPreview() {
    EatAppTheme {
        StatisticsContent(uiState = previewUiState, onBack = {})
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun StatisticsScreenEmptyPreview() {
    EatAppTheme {
        StatisticsContent(uiState = StatisticsUiState(isInitialLoad = false), onBack = {})
    }
}
