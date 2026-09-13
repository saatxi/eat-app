package com.saatxi.eatapp.ui.stats

import android.content.res.Configuration
import androidx.compose.foundation.Canvas
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import com.saatxi.eatapp.R
import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.TagCount
import com.saatxi.eatapp.ui.common.cuisineIcon
import com.saatxi.eatapp.ui.common.cuisineLabel
import com.saatxi.eatapp.ui.common.cuisineTint
import com.saatxi.eatapp.ui.common.priceRangeLabel
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
                    // level when one label wraps onto two lines and the others don't — at a
                    // large system font scale "Want to try"/"Per provar" can wrap while
                    // "Visitats"/"Visited" stays on one line, and without this the wrapped
                    // tile's card would grow taller than its neighbours instead of them all
                    // matching it.
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

                    if (uiState.monthlyVisitCounts.any { it.count > 0 }) {
                        StatsCard(title = stringResource(R.string.stats_section_visits_per_month)) {
                            VisitsPerMonthChart(
                                counts = uiState.monthlyVisitCounts,
                                modifier = Modifier.fillMaxWidth().height(120.dp)
                            )
                        }
                    }

                    if (uiState.monthlyRatingTrend.count { it.average != null } >= 2) {
                        StatsCard(title = stringResource(R.string.stats_section_rating_trend)) {
                            RatingTrendPerMonthChart(
                                points = uiState.monthlyRatingTrend,
                                modifier = Modifier.fillMaxWidth().height(120.dp)
                            )
                        }
                    }

                    if (uiState.tagCounts.isNotEmpty()) {
                        val maxCount = uiState.tagCounts.maxOf { it.count }
                        StatsCard(title = stringResource(R.string.stats_section_top_tags)) {
                            uiState.tagCounts.forEach { tagCount ->
                                TagBarRow(tagCount = tagCount, maxCount = maxCount)
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
                priceRangeLabel(priceRangeCount.priceRange)
            },
            style = MaterialTheme.typography.labelMedium,
            modifier = Modifier.width(84.dp)
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

@Composable
private fun TagBarRow(tagCount: TagCount, maxCount: Int) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = tagCount.name,
            style = MaterialTheme.typography.labelMedium,
            maxLines = 1,
            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
            modifier = Modifier.width(96.dp)
        )
        StatBar(
            fraction = tagCount.count.toFloat() / maxCount,
            color = MaterialTheme.colorScheme.secondary,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = tagCount.count.toString(),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 8.dp)
        )
    }
}

/**
 * Canvas-drawn bar chart of visits per month, last [MonthlyVisitCount]s
 * oldest-to-newest — this project has no charting library, so bars are drawn
 * directly with `drawScope.drawRoundRect`, matching the mockup's bar-chart
 * treatment. A short "MMM" label sits under each bar.
 */
@Composable
private fun VisitsPerMonthChart(counts: List<MonthlyVisitCount>, modifier: Modifier = Modifier) {
    val barColor = MaterialTheme.colorScheme.primary
    val labelColor = MaterialTheme.colorScheme.onSurfaceVariant
    val labelPaint = remember {
        android.graphics.Paint().apply {
            textAlign = android.graphics.Paint.Align.CENTER
            textSize = 28f
        }
    }
    val maxCount = (counts.maxOfOrNull { it.count } ?: 0).coerceAtLeast(1)

    Canvas(modifier = modifier) {
        if (counts.isEmpty() || size.width <= 0f || size.height <= 0f) return@Canvas
        labelPaint.color = labelColor.toArgb()

        val labelHeight = 32f
        val chartHeight = size.height - labelHeight
        val slotWidth = size.width / counts.size
        val barWidth = slotWidth * 0.5f

        counts.forEachIndexed { index, monthCount ->
            val barHeight = chartHeight * (monthCount.count.toFloat() / maxCount)
            val left = index * slotWidth + (slotWidth - barWidth) / 2
            drawRoundRect(
                color = barColor,
                topLeft = Offset(left, chartHeight - barHeight),
                size = Size(barWidth, barHeight.coerceAtLeast(2f)),
                cornerRadius = CornerRadius(4.dp.toPx(), 4.dp.toPx())
            )
            drawContext.canvas.nativeCanvas.drawText(
                monthCount.monthKey.takeLast(2),
                index * slotWidth + slotWidth / 2,
                size.height - 4f,
                labelPaint
            )
        }
    }
}

/** Rating axis ceiling for [RatingTrendPerMonthChart] — see `Visit.rating`. */
private const val MAX_RATING_TREND = 5f

/**
 * Canvas-drawn line chart of the average rating across every restaurant, one
 * point per month, months with no visits skipped rather than drawn as zero —
 * global counterpart to `RestaurantDetailScreen`'s per-restaurant
 * `RatingTrendChart`, aggregating across restaurants instead of following one.
 */
@Composable
private fun RatingTrendPerMonthChart(points: List<MonthlyAverageRating>, modifier: Modifier = Modifier) {
    val lineColor = MaterialTheme.colorScheme.primary
    val plotted = points.mapIndexedNotNull { index, point -> point.average?.let { index to it } }

    Canvas(modifier = modifier) {
        if (plotted.size < 2 || size.width <= 0f || size.height <= 0f) return@Canvas

        val slotWidth = if (points.size > 1) size.width / (points.size - 1) else size.width
        val offsets = plotted.map { (index, average) ->
            Offset(
                x = index * slotWidth,
                y = size.height * (1f - (average.toFloat() / MAX_RATING_TREND))
            )
        }

        val path = androidx.compose.ui.graphics.Path().apply {
            moveTo(offsets.first().x, offsets.first().y)
            offsets.drop(1).forEach { lineTo(it.x, it.y) }
        }
        drawPath(path = path, color = lineColor, style = androidx.compose.ui.graphics.drawscope.Stroke(width = 3.dp.toPx()))
        offsets.forEach { offset -> drawCircle(color = lineColor, radius = 4.dp.toPx(), center = offset) }
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
    monthlyRatingTrend = listOf(
        MonthlyAverageRating("2026-04", 3.5),
        MonthlyAverageRating("2026-05", 3.8),
        MonthlyAverageRating("2026-06", 4.1),
        MonthlyAverageRating("2026-07", 3.9),
        MonthlyAverageRating("2026-08", null),
        MonthlyAverageRating("2026-09", 4.3)
    ),
    monthlyVisitCounts = listOf(
        MonthlyVisitCount("2026-04", 1),
        MonthlyVisitCount("2026-05", 3),
        MonthlyVisitCount("2026-06", 2),
        MonthlyVisitCount("2026-07", 4),
        MonthlyVisitCount("2026-08", 0),
        MonthlyVisitCount("2026-09", 2)
    ),
    tagCounts = listOf(
        TagCount("Terraza", 6),
        TagCount("Para grupos", 4),
        TagCount("Brunch", 2)
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
