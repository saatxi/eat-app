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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.AddAPhoto
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import com.saatxi.eatapp.R
import com.saatxi.eatapp.data.local.Cuisine
import com.saatxi.eatapp.ui.AppViewModelProvider
import com.saatxi.eatapp.ui.common.cuisineIcon
import com.saatxi.eatapp.ui.common.cuisineLabel
import com.saatxi.eatapp.ui.theme.EatAppTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RestaurantEditScreen(
    onBack: () -> Unit,
    restaurantId: Long?,
    viewModel: RestaurantEditViewModel = viewModel(
        key = "edit-${restaurantId ?: "new"}",
        factory = AppViewModelProvider.editViewModelFactory(restaurantId)
    )
) {
    val uiState by viewModel.uiState.collectAsState()
    RestaurantEditContent(
        uiState = uiState,
        isEditingExisting = viewModel.isEditingExisting,
        onBack = onBack,
        onNameChange = viewModel::onNameChange,
        onCuisineChange = viewModel::onCuisineChange,
        onAddressChange = viewModel::onAddressChange,
        onVisitedChange = viewModel::onVisitedChange,
        onRatingChange = viewModel::onRatingChange,
        onPriceRangeChange = viewModel::onPriceRangeChange,
        onWebsiteChange = viewModel::onWebsiteChange,
        onInstagramChange = viewModel::onInstagramChange,
        onPhotoPicked = viewModel::onPhotoPicked,
        onRemovePhoto = viewModel::onRemovePhoto,
        onSave = { viewModel.onSave(onSaved = onBack) }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RestaurantEditContent(
    uiState: RestaurantEditUiState,
    isEditingExisting: Boolean,
    onBack: () -> Unit,
    onNameChange: (String) -> Unit,
    onCuisineChange: (String) -> Unit,
    onAddressChange: (String) -> Unit,
    onVisitedChange: (Boolean) -> Unit,
    onRatingChange: (Int) -> Unit,
    onPriceRangeChange: (Int) -> Unit,
    onWebsiteChange: (String) -> Unit,
    onInstagramChange: (String) -> Unit,
    onPhotoPicked: (Uri) -> Unit,
    onRemovePhoto: () -> Unit,
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
            PhotoPicker(
                previewPhoto = uiState.previewPhoto,
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
                    value = uiState.address,
                    onValueChange = onAddressChange,
                    label = { Text(stringResource(R.string.edit_field_address)) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            EditSectionCard(title = stringResource(R.string.edit_section_status_rating)) {
                Column {
                    Text(stringResource(R.string.edit_field_visit_status), style = MaterialTheme.typography.labelLarge)
                    SingleChoiceSegmentedButtonRow(modifier = Modifier.padding(top = 4.dp)) {
                        SegmentedButton(
                            selected = !uiState.visited,
                            onClick = { onVisitedChange(false) },
                            shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2)
                        ) {
                            Text(stringResource(R.string.visit_status_want_to_try))
                        }
                        SegmentedButton(
                            selected = uiState.visited,
                            onClick = { onVisitedChange(true) },
                            shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2)
                        ) {
                            Text(stringResource(R.string.visit_status_visited))
                        }
                    }
                }

                Column {
                    Text(stringResource(R.string.edit_field_rating), style = MaterialTheme.typography.labelLarge)
                    RatingPicker(
                        rating = uiState.rating,
                        onRatingChange = onRatingChange,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }

                Column {
                    Text(stringResource(R.string.edit_field_price_range), style = MaterialTheme.typography.labelLarge)
                    PriceRangePicker(
                        priceRange = uiState.priceRange,
                        onPriceRangeChange = onPriceRangeChange,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
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

/**
 * A tappable preview box that opens the system Photo Picker — no storage
 * permission needed, on API 26+ through the picker's own backport — and shows
 * either the resulting pick (or, in edit mode, the already-stored photo) or a
 * plain placeholder when there is none. [previewPhoto] is whatever
 * [RestaurantEditUiState.previewPhoto] resolves to: a picked [Uri], an
 * absolute path [String] to an existing photo, or null.
 */
@Composable
private fun PhotoPicker(
    previewPhoto: Any?,
    onPhotoPicked: (Uri) -> Unit,
    onRemovePhoto: () -> Unit
) {
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) onPhotoPicked(uri)
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(160.dp)
            .clip(MaterialTheme.shapes.medium)
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .clickable {
                launcher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
        contentAlignment = Alignment.Center
    ) {
        if (previewPhoto != null) {
            AsyncImage(
                model = previewPhoto,
                contentDescription = stringResource(R.string.edit_photo_preview_description),
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
            IconButton(
                onClick = onRemovePhoto,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(8.dp)
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(Color.Black.copy(alpha = 0.45f))
            ) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = stringResource(R.string.edit_action_remove_photo),
                    tint = Color.White
                )
            }
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    Icons.Outlined.AddAPhoto,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = stringResource(R.string.edit_action_add_photo),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
        }
    }
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

@Composable
private fun RatingPicker(rating: Int, onRatingChange: (Int) -> Unit, modifier: Modifier = Modifier) {
    Row(modifier = modifier) {
        (1..5).forEach { star ->
            IconButton(onClick = { onRatingChange(if (rating == star) star - 1 else star) }) {
                Icon(
                    imageVector = if (star <= rating) Icons.Filled.Star else Icons.Outlined.Star,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

@Composable
private fun PriceRangePicker(priceRange: Int, onPriceRangeChange: (Int) -> Unit, modifier: Modifier = Modifier) {
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        (1..4).forEach { level ->
            val selected = level <= priceRange
            Surface(
                onClick = { onPriceRangeChange(if (priceRange == level) level - 1 else level) },
                shape = MaterialTheme.shapes.small,
                color = if (selected) MaterialTheme.colorScheme.tertiaryContainer else MaterialTheme.colorScheme.surfaceVariant
            ) {
                Text(
                    text = "$".repeat(level),
                    style = MaterialTheme.typography.labelLarge,
                    color = if (selected) {
                        MaterialTheme.colorScheme.onTertiaryContainer
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
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
            uiState = RestaurantEditUiState(name = "Cal Ferran", cuisineType = "mediterranean", rating = 4, priceRange = 2),
            isEditingExisting = false,
            onBack = {},
            onNameChange = {},
            onCuisineChange = {},
            onAddressChange = {},
            onVisitedChange = {},
            onRatingChange = {},
            onPriceRangeChange = {},
            onWebsiteChange = {},
            onInstagramChange = {},
            onPhotoPicked = {},
            onRemovePhoto = {},
            onSave = {}
        )
    }
}
