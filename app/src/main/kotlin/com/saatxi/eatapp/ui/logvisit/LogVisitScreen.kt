package com.saatxi.eatapp.ui.logvisit

import android.content.res.Configuration
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.AddAPhoto
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.Card
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
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
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import coil3.compose.AsyncImage
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.common.PriceRangePicker
import com.saatxi.eatapp.ui.theme.EatAppTheme
import java.text.DateFormat
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LogVisitScreen(
    onDone: () -> Unit,
    viewModel: LogVisitViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    LogVisitContent(
        uiState = uiState,
        onBack = onDone,
        onDateChange = viewModel::onDateChange,
        onRatingChange = viewModel::onRatingChange,
        onPriceRangeChange = viewModel::onPriceRangeChange,
        onNotesChange = viewModel::onNotesChange,
        onPhotoPicked = viewModel::onPhotoPicked,
        onRemovePhoto = viewModel::onRemovePhoto,
        onSave = { viewModel.onSave(onSaved = onDone) }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LogVisitContent(
    uiState: LogVisitUiState,
    onBack: () -> Unit,
    onDateChange: (Long) -> Unit,
    onRatingChange: (Int) -> Unit,
    onPriceRangeChange: (Int) -> Unit,
    onNotesChange: (String) -> Unit,
    onPhotoPicked: (Uri) -> Unit,
    onRemovePhoto: (String) -> Unit,
    onSave: () -> Unit
) {
    var showDatePicker by remember { mutableStateOf(false) }
    val dateFormatter = remember { DateFormat.getDateInstance(DateFormat.MEDIUM) }

    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(initialSelectedDateMillis = uiState.visitDate)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let(onDateChange)
                    showDatePicker = false
                }) {
                    Text(stringResource(R.string.logvisit_date_picker_confirm))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text(stringResource(R.string.logvisit_date_picker_cancel))
                }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.logvisit_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.action_back))
                    }
                },
                actions = {
                    IconButton(onClick = onSave) {
                        Icon(Icons.Default.Check, contentDescription = stringResource(R.string.logvisit_action_save))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Column {
                        Text(stringResource(R.string.logvisit_field_date), style = MaterialTheme.typography.labelLarge)
                        OutlinedTextField(
                            value = dateFormatter.format(Date(uiState.visitDate)),
                            onValueChange = {},
                            readOnly = true,
                            singleLine = true,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 4.dp)
                                .clickable { showDatePicker = true }
                        )
                    }

                    Column {
                        Text(stringResource(R.string.logvisit_field_rating), style = MaterialTheme.typography.labelLarge)
                        RatingPicker(
                            rating = uiState.rating,
                            onRatingChange = onRatingChange,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }

                    Column {
                        Text(stringResource(R.string.logvisit_field_price), style = MaterialTheme.typography.labelLarge)
                        PriceRangePicker(
                            priceRange = uiState.priceRange,
                            onPriceRangeChange = onPriceRangeChange,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }

                    OutlinedTextField(
                        value = uiState.notes,
                        onValueChange = onNotesChange,
                        label = { Text(stringResource(R.string.logvisit_field_notes)) },
                        minLines = 3,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            VisitPhotoStrip(
                photoPaths = uiState.photoPaths,
                onPhotoPicked = onPhotoPicked,
                onRemovePhoto = onRemovePhoto
            )
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

/**
 * A horizontal strip of already-copied photos for this visit, each removable,
 * plus a trailing "add" tile that opens the system Photo Picker — unlike the
 * edit form's single-photo box, a visit can carry several.
 */
@Composable
private fun VisitPhotoStrip(
    photoPaths: List<String>,
    onPhotoPicked: (Uri) -> Unit,
    onRemovePhoto: (String) -> Unit
) {
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) onPhotoPicked(uri)
    }

    Row(
        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        photoPaths.forEach { path ->
            Box(modifier = Modifier.size(88.dp)) {
                AsyncImage(
                    model = path,
                    contentDescription = stringResource(R.string.logvisit_photo_description),
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(MaterialTheme.shapes.small)
                )
                IconButton(
                    onClick = { onRemovePhoto(path) },
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(2.dp)
                        .size(24.dp)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.45f))
                ) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = stringResource(R.string.logvisit_action_remove_photo),
                        tint = Color.White,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
        Box(
            modifier = Modifier
                .size(88.dp)
                .clip(MaterialTheme.shapes.small)
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .clickable {
                    launcher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                },
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    Icons.Outlined.AddAPhoto,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = stringResource(R.string.logvisit_action_add_photo),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 2.dp)
                )
            }
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun LogVisitScreenPreview() {
    EatAppTheme {
        LogVisitContent(
            uiState = LogVisitUiState(rating = 4, priceRange = 2, notes = "Ask for the burrata to start."),
            onBack = {},
            onDateChange = {},
            onRatingChange = {},
            onPriceRangeChange = {},
            onNotesChange = {},
            onPhotoPicked = {},
            onRemovePhoto = {},
            onSave = {}
        )
    }
}
