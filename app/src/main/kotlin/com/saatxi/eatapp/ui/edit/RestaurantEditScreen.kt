package com.saatxi.eatapp.ui.edit

import android.content.res.Configuration
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.AddAPhoto
import androidx.compose.material.icons.outlined.MyLocation
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.InputChip
import androidx.compose.material3.InputChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import coil3.compose.AsyncImage
import com.saatxi.eatapp.R
import com.saatxi.eatapp.data.local.Cuisine
import com.saatxi.eatapp.ui.common.AutocompleteTextField
import com.saatxi.eatapp.ui.common.PriceRangePicker
import com.saatxi.eatapp.ui.common.cuisineIcon
import com.saatxi.eatapp.ui.common.cuisineLabel
import com.saatxi.eatapp.ui.theme.EatAppTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RestaurantEditScreen(
    onBack: () -> Unit,
    restaurantId: String?,
    viewModel: RestaurantEditViewModel = hiltViewModel(key = "edit-${restaurantId ?: "new"}")
) {
    val uiState by viewModel.uiState.collectAsState()
    val tagSuggestions by viewModel.tagSuggestions.collectAsState()
    val citySuggestions by viewModel.citySuggestions.collectAsState()
    val regionSuggestions by viewModel.regionSuggestions.collectAsState()
    val countrySuggestions by viewModel.countrySuggestions.collectAsState()
    RestaurantEditContent(
        uiState = uiState,
        isEditingExisting = viewModel.isEditingExisting,
        tagSuggestions = tagSuggestions,
        citySuggestions = citySuggestions,
        regionSuggestions = regionSuggestions,
        countrySuggestions = countrySuggestions,
        onBack = onBack,
        onNameChange = viewModel::onNameChange,
        onCuisineChange = viewModel::onCuisineChange,
        onStreetAddressChange = viewModel::onStreetAddressChange,
        onCityChange = viewModel::onCityChange,
        onRegionChange = viewModel::onRegionChange,
        onCountryChange = viewModel::onCountryChange,
        onLatitudeChange = viewModel::onLatitudeChange,
        onLongitudeChange = viewModel::onLongitudeChange,
        onGeocodeAddress = viewModel::onGeocodeAddress,
        onPriceRangeChange = viewModel::onPriceRangeChange,
        onWebsiteChange = viewModel::onWebsiteChange,
        onInstagramChange = viewModel::onInstagramChange,
        onPhotoPicked = viewModel::onPhotoPicked,
        onRemovePhoto = viewModel::onRemovePhoto,
        onAddTag = viewModel::onAddTag,
        onRemoveTag = viewModel::onRemoveTag,
        onSave = { viewModel.onSave(onSaved = onBack) }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RestaurantEditContent(
    uiState: RestaurantEditUiState,
    isEditingExisting: Boolean,
    tagSuggestions: List<String>,
    citySuggestions: List<String>,
    regionSuggestions: List<String>,
    countrySuggestions: List<String>,
    onBack: () -> Unit,
    onNameChange: (String) -> Unit,
    onCuisineChange: (String) -> Unit,
    onStreetAddressChange: (String) -> Unit,
    onCityChange: (String) -> Unit,
    onRegionChange: (String) -> Unit,
    onCountryChange: (String) -> Unit,
    onLatitudeChange: (String) -> Unit,
    onLongitudeChange: (String) -> Unit,
    onGeocodeAddress: () -> Unit,
    onPriceRangeChange: (Int) -> Unit,
    onWebsiteChange: (String) -> Unit,
    onInstagramChange: (String) -> Unit,
    onPhotoPicked: (Uri) -> Unit,
    onRemovePhoto: (String) -> Unit,
    onAddTag: (String) -> Unit,
    onRemoveTag: (String) -> Unit,
    onSave: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        stringResource(
                            if (isEditingExisting) R.string.edit_title_edit else R.string.edit_title_add
                        )
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.action_back))
                    }
                },
                actions = {
                    IconButton(onClick = onSave) {
                        Icon(Icons.Default.Check, contentDescription = stringResource(R.string.edit_action_save))
                    }
                }
            )
        }
    ) { padding ->
        if (uiState.isLoading) {
            Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            return@Scaffold
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            PhotoCarousel(
                photoPaths = uiState.photoPaths,
                onPhotoPicked = onPhotoPicked,
                onRemovePhoto = onRemovePhoto
            )

            EditSectionCard(title = stringResource(R.string.edit_section_basics)) {
                OutlinedTextField(
                    value = uiState.name,
                    onValueChange = onNameChange,
                    label = { Text(stringResource(R.string.edit_field_name)) },
                    isError = uiState.nameError,
                    supportingText = {
                        if (uiState.nameError) Text(stringResource(R.string.edit_error_name_required))
                    },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                    modifier = Modifier.fillMaxWidth()
                )

                CuisineDropdown(
                    selected = uiState.cuisineType,
                    isError = uiState.cuisineError,
                    onSelect = onCuisineChange
                )

                OutlinedTextField(
                    value = uiState.streetAddress,
                    onValueChange = onStreetAddressChange,
                    label = { Text(stringResource(R.string.edit_field_address)) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                    modifier = Modifier.fillMaxWidth()
                )

                AutocompleteTextField(
                    value = uiState.city,
                    onValueChange = onCityChange,
                    suggestions = citySuggestions,
                    label = { Text(stringResource(R.string.edit_field_city)) }
                )

                AutocompleteTextField(
                    value = uiState.region,
                    onValueChange = onRegionChange,
                    suggestions = regionSuggestions,
                    label = { Text(stringResource(R.string.edit_field_region)) }
                )

                AutocompleteTextField(
                    value = uiState.country,
                    onValueChange = onCountryChange,
                    suggestions = countrySuggestions,
                    label = { Text(stringResource(R.string.edit_field_country)) }
                )

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    OutlinedTextField(
                        value = uiState.latitude,
                        onValueChange = onLatitudeChange,
                        label = { Text(stringResource(R.string.edit_field_latitude)) },
                        isError = uiState.latitudeError,
                        supportingText = {
                            if (uiState.latitudeError) Text(stringResource(R.string.edit_error_latitude_invalid))
                        },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.weight(1f)
                    )
                    OutlinedTextField(
                        value = uiState.longitude,
                        onValueChange = onLongitudeChange,
                        label = { Text(stringResource(R.string.edit_field_longitude)) },
                        isError = uiState.longitudeError,
                        supportingText = {
                            if (uiState.longitudeError) Text(stringResource(R.string.edit_error_longitude_invalid))
                        },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.weight(1f)
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = onGeocodeAddress, enabled = !uiState.isGeocoding) {
                        if (uiState.isGeocoding) {
                            CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                            Text(stringResource(R.string.edit_action_geocode), modifier = Modifier.padding(start = 8.dp))
                        } else {
                            Icon(Icons.Outlined.MyLocation, contentDescription = null, modifier = Modifier.size(18.dp))
                            Text(stringResource(R.string.edit_action_geocode), modifier = Modifier.padding(start = 8.dp))
                        }
                    }
                }
                if (uiState.geocodeError) {
                    Text(
                        text = stringResource(R.string.edit_error_geocode_not_found),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }

            EditSectionCard(title = stringResource(R.string.edit_field_price_range)) {
                PriceRangePicker(
                    priceRange = uiState.priceRange,
                    onPriceRangeChange = onPriceRangeChange
                )
            }

            EditSectionCard(title = stringResource(R.string.edit_section_links)) {
                OutlinedTextField(
                    value = uiState.website,
                    onValueChange = onWebsiteChange,
                    label = { Text(stringResource(R.string.edit_field_website)) },
                    isError = uiState.websiteError,
                    supportingText = {
                        if (uiState.websiteError) Text(stringResource(R.string.edit_error_website_invalid))
                    },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = uiState.instagram,
                    onValueChange = onInstagramChange,
                    label = { Text(stringResource(R.string.edit_field_instagram)) },
                    isError = uiState.instagramError,
                    supportingText = {
                        if (uiState.instagramError) Text(stringResource(R.string.edit_error_instagram_invalid))
                    },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            EditSectionCard(title = stringResource(R.string.edit_section_tags)) {
                TagsField(
                    tags = uiState.tags,
                    suggestions = tagSuggestions,
                    onAddTag = onAddTag,
                    onRemoveTag = onRemoveTag
                )
            }
        }
    }
}

/**
 * The chip-entry field for free-form tags (F-59): a text field that commits
 * a tag on IME "Done" or a typed comma, existing-tag suggestions filtered by
 * what's typed so far (tap to add), and the tags already added as removable
 * chips. [tags]/[suggestions] are the source of truth — this composable only
 * holds the in-progress text, never the committed list.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TagsField(
    tags: List<String>,
    suggestions: List<String>,
    onAddTag: (String) -> Unit,
    onRemoveTag: (String) -> Unit
) {
    var input by remember { mutableStateOf("") }

    fun commit(raw: String) {
        onAddTag(raw)
        input = ""
    }

    OutlinedTextField(
        value = input,
        onValueChange = { value ->
            if (value.endsWith(",")) commit(value.dropLast(1)) else input = value
        },
        label = { Text(stringResource(R.string.edit_field_tags)) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            capitalization = KeyboardCapitalization.Sentences,
            imeAction = ImeAction.Done
        ),
        keyboardActions = KeyboardActions(onDone = { commit(input) }),
        modifier = Modifier.fillMaxWidth()
    )

    val matchingSuggestions = if (input.isBlank()) {
        emptyList()
    } else {
        suggestions.filter { suggestion ->
            suggestion.contains(input, ignoreCase = true) && tags.none { it.equals(suggestion, ignoreCase = true) }
        }
    }
    if (matchingSuggestions.isNotEmpty()) {
        val chipColors = FilterChipDefaults.filterChipColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant,
            labelColor = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            matchingSuggestions.forEach { suggestion ->
                FilterChip(
                    selected = false,
                    onClick = { commit(suggestion) },
                    label = { Text(suggestion) },
                    colors = chipColors
                )
            }
        }
    }

    if (tags.isNotEmpty()) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            tags.forEach { tag ->
                InputChip(
                    selected = false,
                    onClick = { onRemoveTag(tag) },
                    label = { Text(tag) },
                    trailingIcon = {
                        Icon(
                            Icons.Default.Close,
                            contentDescription = stringResource(R.string.edit_action_remove_tag, tag),
                            modifier = Modifier.size(InputChipDefaults.IconSize)
                        )
                    }
                )
            }
        }
    }
}

/**
 * One titled card grouping a handful of related fields — the same
 * [Card] + title-then-content shape [RestaurantDetailScreen] uses for its own
 * Overview / Rating and price / Links cards, so the form now reads as the
 * same kind of document as the screen that shows it back.
 */
@Composable
private fun EditSectionCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(text = title, style = MaterialTheme.typography.titleMedium)
            content()
        }
    }
}

/** Size of one square photo tile in [PhotoCarousel] — both the filled and the dashed "add" tile. */
private val PHOTO_TILE_SIZE = 96.dp

/**
 * A horizontal-scrolling row of the restaurant's photos, each with a small
 * remove badge, plus a trailing dashed-border "add" tile that opens the
 * system Photo Picker — no storage permission needed, on API 26+ through the
 * picker's own backport. Mirrors the mockup's "Editar restaurante" carousel
 * treatment; [photoPaths] is [RestaurantEditUiState.photoPaths].
 */
@Composable
private fun PhotoCarousel(
    photoPaths: List<String>,
    onPhotoPicked: (Uri) -> Unit,
    onRemovePhoto: (String) -> Unit
) {
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) onPhotoPicked(uri)
    }

    LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        items(photoPaths, key = { it }) { path ->
            PhotoTile(path = path, onRemove = { onRemovePhoto(path) })
        }
        item(key = "add") {
            AddPhotoTile(
                onClick = { launcher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
            )
        }
    }
}

@Composable
private fun PhotoTile(path: String, onRemove: () -> Unit) {
    Box(modifier = Modifier.size(PHOTO_TILE_SIZE)) {
        AsyncImage(
            model = path,
            contentDescription = stringResource(R.string.edit_photo_preview_description),
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .clip(MaterialTheme.shapes.medium)
        )
        IconButton(
            onClick = onRemove,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(4.dp)
                .size(24.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.45f))
        ) {
            Icon(
                Icons.Default.Close,
                contentDescription = stringResource(R.string.edit_action_remove_photo),
                tint = Color.White,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

/** Corner radius of the "add" tile's dashed border — matches `MaterialTheme.shapes.medium`'s own rounding. */
private val PHOTO_TILE_CORNER_RADIUS = 12.dp

@Composable
private fun AddPhotoTile(onClick: () -> Unit) {
    val outlineColor = MaterialTheme.colorScheme.outline
    Box(
        modifier = Modifier
            .size(PHOTO_TILE_SIZE)
            .clip(MaterialTheme.shapes.medium)
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .dashedBorder(color = outlineColor, cornerRadius = PHOTO_TILE_CORNER_RADIUS)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                Icons.Outlined.AddAPhoto,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = stringResource(R.string.edit_action_add_photo),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 2.dp)
            )
        }
    }
}

/** A dashed rounded-rect outline, per the mockup's "add" tile — Compose has no built-in dashed [Modifier.border]. */
private fun Modifier.dashedBorder(color: Color, cornerRadius: Dp, width: Dp = 1.5.dp) =
    this.drawWithContent {
        drawContent()
        val strokeWidthPx = width.toPx()
        // Inset by half the stroke width so the dashed line draws fully inside the tile's bounds.
        val inset = strokeWidthPx / 2
        drawRoundRect(
            color = color,
            topLeft = Offset(inset, inset),
            size = Size(size.width - strokeWidthPx, size.height - strokeWidthPx),
            cornerRadius = CornerRadius(cornerRadius.toPx(), cornerRadius.toPx()),
            style = Stroke(width = strokeWidthPx, pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f)))
        )
    }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CuisineDropdown(
    selected: String?,
    isError: Boolean,
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val label = selected?.let { cuisineLabel(it) } ?: ""

    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = label,
            onValueChange = {},
            readOnly = true,
            label = { Text(stringResource(R.string.edit_field_cuisine)) },
            placeholder = { Text(stringResource(R.string.edit_cuisine_placeholder)) },
            isError = isError,
            supportingText = {
                if (isError) Text(stringResource(R.string.edit_error_cuisine_required))
            },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier.fillMaxWidth().menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable)
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            Cuisine.entries.forEach { cuisine ->
                DropdownMenuItem(
                    text = { Text(cuisineLabel(cuisine.key)) },
                    leadingIcon = {
                        Icon(cuisineIcon(cuisine.key), contentDescription = null)
                    },
                    onClick = {
                        onSelect(cuisine.key)
                        expanded = false
                    }
                )
            }
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RestaurantEditScreenPreview() {
    EatAppTheme {
        RestaurantEditContent(
            uiState = RestaurantEditUiState(
                name = "Cal Ferran",
                cuisineType = "mediterranean",
                priceRange = 2,
                tags = listOf("Terraza", "Para grupos")
            ),
            isEditingExisting = false,
            tagSuggestions = listOf("Terraza", "Para grupos", "Brunch"),
            citySuggestions = listOf("Girona", "Barcelona"),
            regionSuggestions = listOf("Girona (província)"),
            countrySuggestions = listOf("Spain", "France"),
            onBack = {},
            onNameChange = {},
            onCuisineChange = {},
            onStreetAddressChange = {},
            onCityChange = {},
            onRegionChange = {},
            onCountryChange = {},
            onLatitudeChange = {},
            onLongitudeChange = {},
            onGeocodeAddress = {},
            onPriceRangeChange = {},
            onWebsiteChange = {},
            onInstagramChange = {},
            onPhotoPicked = {},
            onRemovePhoto = {},
            onAddTag = {},
            onRemoveTag = {},
            onSave = {}
        )
    }
}
