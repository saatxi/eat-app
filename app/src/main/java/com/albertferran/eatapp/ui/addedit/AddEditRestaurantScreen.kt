package com.albertferran.eatapp.ui.addedit

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.albertferran.eatapp.R
import com.albertferran.eatapp.ui.AppViewModelProvider
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditRestaurantScreen(
    onSaved: () -> Unit,
    onBack: () -> Unit,
    viewModel: AddEditRestaurantViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(uiState.isSaved) {
        if (uiState.isSaved) onSaved()
    }

    val isNew = uiState.id == AddEditRestaurantViewModel.NEW_RESTAURANT_ID

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(if (isNew) R.string.add_edit_title_new else R.string.add_edit_title_edit)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.action_back))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState())
        ) {
            OutlinedTextField(
                value = uiState.name,
                onValueChange = viewModel::onNameChange,
                label = { Text(stringResource(R.string.add_edit_field_name)) },
                isError = uiState.nameError,
                supportingText = {
                    if (uiState.nameError) Text(stringResource(R.string.add_edit_error_name_required))
                },
                modifier = Modifier.fillMaxWidth()
            )

            OutlinedTextField(
                value = uiState.cuisineType,
                onValueChange = viewModel::onCuisineTypeChange,
                label = { Text(stringResource(R.string.add_edit_field_cuisine_type)) },
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp)
            )

            OutlinedTextField(
                value = uiState.address,
                onValueChange = viewModel::onAddressChange,
                label = { Text(stringResource(R.string.add_edit_field_address)) },
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp)
            )

            Text(stringResource(R.string.add_edit_field_rating), modifier = Modifier.padding(top = 16.dp))
            Row {
                (1..5).forEach { star ->
                    IconButton(onClick = { viewModel.onRatingChange(star) }) {
                        Icon(
                            imageVector = if (star <= uiState.rating) Icons.Filled.Star else Icons.Outlined.Star,
                            contentDescription = null
                        )
                    }
                }
            }

            Text(stringResource(R.string.add_edit_field_price_range), modifier = Modifier.padding(top = 8.dp))
            Row {
                (1..4).forEach { level ->
                    FilterChip(
                        selected = uiState.priceRange == level,
                        onClick = { viewModel.onPriceRangeChange(level) },
                        label = { Text("$".repeat(level)) },
                        modifier = Modifier.padding(end = 8.dp)
                    )
                }
            }

            OutlinedTextField(
                value = uiState.notes,
                onValueChange = viewModel::onNotesChange,
                label = { Text(stringResource(R.string.add_edit_field_notes)) },
                minLines = 3,
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp)
            )

            var showDatePicker by remember { mutableStateOf(false) }
            Text(stringResource(R.string.add_edit_field_visit_date), modifier = Modifier.padding(top = 16.dp))
            OutlinedButton(onClick = { showDatePicker = true }, modifier = Modifier.padding(top = 4.dp)) {
                Text(uiState.visitDate.format(DateTimeFormatter.ISO_LOCAL_DATE))
            }
            if (showDatePicker) {
                val datePickerState = rememberDatePickerState(
                    initialSelectedDateMillis = uiState.visitDate
                        .atStartOfDay(ZoneOffset.UTC)
                        .toInstant()
                        .toEpochMilli()
                )
                DatePickerDialog(
                    onDismissRequest = { showDatePicker = false },
                    confirmButton = {
                        TextButton(onClick = {
                            datePickerState.selectedDateMillis?.let { millis ->
                                val date = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
                                viewModel.onVisitDateChange(date)
                            }
                            showDatePicker = false
                        }) { Text(stringResource(R.string.add_edit_action_save)) }
                    },
                    dismissButton = {
                        TextButton(onClick = { showDatePicker = false }) {
                            Text(stringResource(R.string.detail_delete_confirm_cancel))
                        }
                    }
                ) {
                    DatePicker(state = datePickerState)
                }
            }

            Button(
                onClick = viewModel::save,
                modifier = Modifier.fillMaxWidth().padding(top = 24.dp)
            ) {
                Text(stringResource(R.string.add_edit_action_save))
            }
        }
    }
}
