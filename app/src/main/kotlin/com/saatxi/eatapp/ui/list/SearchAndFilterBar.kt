package com.saatxi.eatapp.ui.list

import android.content.res.Configuration
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.Badge
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SelectableChipColors
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.saatxi.eatapp.R
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.ui.common.cuisineIcon
import com.saatxi.eatapp.ui.common.cuisineLabel
import com.saatxi.eatapp.ui.theme.EatAppTheme

/**
 * The search field, sort control and filter-chip panel — everything above
 * the list itself. Internal rather than private: [com.saatxi.eatapp.ui.favorites.FavoritesScreen]
 * shows the same kind of list and reuses this exact block rather than a
 * second copy of it (F-60), the same way it already reuses [RestaurantRow]
 * and [EmptyState].
 *
 * [showSortAndFilters] hides the sort/filter section — but never the search
 * field itself — while there's nothing to sort or filter yet (the initial
 * load, or before any restaurant exists at all); each screen computes that
 * condition itself, since "nothing to filter yet" means something slightly
 * different for an unfiltered list versus one already narrowed to favourites.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SearchAndFilterBar(
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    showSortAndFilters: Boolean,
    sort: RestaurantSort,
    onSortChange: (RestaurantSort) -> Unit,
    minRating: Int?,
    onMinRatingChange: (Int?) -> Unit,
    cuisineType: String?,
    availableCuisines: List<String>,
    onCuisineChange: (String?) -> Unit,
    visited: Boolean?,
    onVisitedChange: (Boolean?) -> Unit,
    city: String?,
    availableCities: List<String>,
    onCityChange: (String?) -> Unit,
    region: String?,
    availableRegions: List<String>,
    onRegionChange: (String?) -> Unit,
    country: String?,
    availableCountries: List<String>,
    onCountryChange: (String?) -> Unit,
    modifier: Modifier = Modifier
) {
    // Survives rotation but not process death on purpose: which filters are
    // active is what matters across a config change, not whether the row
    // happened to be open.
    var filtersExpanded by rememberSaveable { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current

    Column(modifier = modifier) {
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchQueryChange,
            // A placeholder rather than a label: the label would float above the
            // text for good once the field has content, costing that height on
            // every screen for a field whose purpose the icon already states.
            placeholder = { Text(stringResource(R.string.list_search_placeholder)) },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            trailingIcon = {
                if (searchQuery.isNotEmpty()) {
                    IconButton(onClick = { onSearchQueryChange("") }) {
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

        if (showSortAndFilters) {
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
                        selected = sort == option,
                        onClick = { onSortChange(option) },
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

            val activeFilterCount = (if (minRating != null) 1 else 0) +
                (if (cuisineType != null) 1 else 0) +
                (if (visited != null) 1 else 0) +
                (if (city != null) 1 else 0) +
                (if (region != null) 1 else 0) +
                (if (country != null) 1 else 0)
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
                    minRating = minRating,
                    onMinRatingChange = onMinRatingChange,
                    cuisineType = cuisineType,
                    availableCuisines = availableCuisines,
                    onCuisineChange = onCuisineChange,
                    visited = visited,
                    onVisitedChange = onVisitedChange,
                    city = city,
                    availableCities = availableCities,
                    onCityChange = onCityChange,
                    region = region,
                    availableRegions = availableRegions,
                    onRegionChange = onRegionChange,
                    country = country,
                    availableCountries = availableCountries,
                    onCountryChange = onCountryChange,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                )
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FilterSection(
    minRating: Int?,
    onMinRatingChange: (Int?) -> Unit,
    cuisineType: String?,
    availableCuisines: List<String>,
    onCuisineChange: (String?) -> Unit,
    visited: Boolean?,
    onVisitedChange: (Boolean?) -> Unit,
    city: String?,
    availableCities: List<String>,
    onCityChange: (String?) -> Unit,
    region: String?,
    availableRegions: List<String>,
    onRegionChange: (String?) -> Unit,
    country: String?,
    availableCountries: List<String>,
    onCountryChange: (String?) -> Unit,
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

        // City/region/country are unbounded free text, unlike the closed cuisine
        // vocabulary above — showing each as its own always-visible chip row
        // would mean up to three horizontally-scrolling rows the moment the
        // user's data spans more than a couple of places. One combined chip
        // opens a sheet with all three instead.
        if (availableCities.isNotEmpty() || availableRegions.isNotEmpty() || availableCountries.isNotEmpty()) {
            var locationSheetOpen by rememberSaveable { mutableStateOf(false) }
            val activeLocationCount = (if (city != null) 1 else 0) +
                (if (region != null) 1 else 0) +
                (if (country != null) 1 else 0)

            Text(
                text = stringResource(R.string.list_filter_location),
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.padding(top = 8.dp)
            )
            Row(modifier = Modifier.padding(vertical = 4.dp)) {
                FilterChip(
                    selected = activeLocationCount > 0,
                    onClick = { locationSheetOpen = true },
                    label = {
                        Text(
                            if (activeLocationCount > 0) {
                                stringResource(R.string.list_filter_location_active, activeLocationCount)
                            } else {
                                stringResource(R.string.list_filter_location)
                            }
                        )
                    },
                    leadingIcon = {
                        Icon(
                            Icons.Outlined.LocationOn,
                            contentDescription = null,
                            modifier = Modifier.size(FilterChipDefaults.IconSize)
                        )
                    },
                    colors = chipColors
                )
            }

            if (locationSheetOpen) {
                val sheetState = rememberModalBottomSheetState()
                ModalBottomSheet(
                    onDismissRequest = { locationSheetOpen = false },
                    sheetState = sheetState
                ) {
                    LocationFilterSheetContent(
                        city = city,
                        availableCities = availableCities,
                        onCityChange = onCityChange,
                        region = region,
                        availableRegions = availableRegions,
                        onRegionChange = onRegionChange,
                        country = country,
                        availableCountries = availableCountries,
                        onCountryChange = onCountryChange,
                        onDone = { locationSheetOpen = false },
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
                    )
                }
            }
        }
    }
}

/**
 * The sheet [FilterSection]'s combined "Location" chip opens: city/region/country as three
 * independent single-select groups, each with an "All" chip that clears that one dimension.
 */
@Composable
private fun LocationFilterSheetContent(
    city: String?,
    availableCities: List<String>,
    onCityChange: (String?) -> Unit,
    region: String?,
    availableRegions: List<String>,
    onRegionChange: (String?) -> Unit,
    country: String?,
    availableCountries: List<String>,
    onCountryChange: (String?) -> Unit,
    onDone: () -> Unit,
    modifier: Modifier = Modifier
) {
    val chipColors = FilterChipDefaults.filterChipColors(
        containerColor = MaterialTheme.colorScheme.surfaceVariant,
        labelColor = MaterialTheme.colorScheme.onSurfaceVariant,
        selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
        selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
    )

    Column(modifier = modifier) {
        Text(text = stringResource(R.string.list_filter_location), style = MaterialTheme.typography.titleMedium)

        LocationFilterGroup(
            label = stringResource(R.string.list_filter_city),
            selected = city,
            options = availableCities,
            onChange = onCityChange,
            chipColors = chipColors,
            modifier = Modifier.padding(top = 16.dp)
        )
        LocationFilterGroup(
            label = stringResource(R.string.list_filter_region),
            selected = region,
            options = availableRegions,
            onChange = onRegionChange,
            chipColors = chipColors,
            modifier = Modifier.padding(top = 16.dp)
        )
        LocationFilterGroup(
            label = stringResource(R.string.list_filter_country),
            selected = country,
            options = availableCountries,
            onChange = onCountryChange,
            chipColors = chipColors,
            modifier = Modifier.padding(top = 16.dp)
        )

        Button(onClick = onDone, modifier = Modifier.fillMaxWidth().padding(top = 20.dp, bottom = 12.dp)) {
            Text(stringResource(R.string.action_done))
        }
    }
}

@Composable
private fun LocationFilterGroup(
    label: String,
    selected: String?,
    options: List<String>,
    onChange: (String?) -> Unit,
    chipColors: SelectableChipColors,
    modifier: Modifier = Modifier
) {
    if (options.isEmpty()) return

    Column(modifier = modifier) {
        Text(text = label, style = MaterialTheme.typography.labelMedium)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = selected == null,
                onClick = { onChange(null) },
                label = { Text(stringResource(R.string.list_filter_all)) },
                colors = chipColors
            )
            options.forEach { option ->
                FilterChip(
                    selected = selected == option,
                    onClick = { onChange(option) },
                    label = { Text(option) },
                    colors = chipColors
                )
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
 * filters, not a separate feature of its own. Two chips rather than three
 * (F-91): a third "top cuisine" chip used to sit here, but on a narrow phone
 * it got cut off at the screen edge with no scroll affordance, so it was
 * dropped rather than fixing the scrolling — the two that always fit are the
 * ones worth keeping visible.
 */
@Composable
internal fun SearchSuggestionsRow(
    onMinRatingChange: (Int?) -> Unit,
    onVisitedChange: (Boolean?) -> Unit,
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
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
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
                onMinRatingChange = {},
                onVisitedChange = {},
                modifier = Modifier.padding(16.dp)
            )
        }
    }
}
