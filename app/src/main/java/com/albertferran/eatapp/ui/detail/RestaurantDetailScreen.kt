package com.albertferran.eatapp.ui.detail

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
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
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RestaurantDetailScreen(
    onEdit: (Long) -> Unit,
    onDeleted: () -> Unit,
    onBack: () -> Unit,
    viewModel: RestaurantDetailViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val restaurant by viewModel.restaurant.collectAsState()
    var showDeleteConfirm by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(restaurant?.name.orEmpty()) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.action_back))
                    }
                },
                actions = {
                    restaurant?.let { current ->
                        IconButton(onClick = { onEdit(current.id) }) {
                            Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.detail_action_edit))
                        }
                        IconButton(onClick = { showDeleteConfirm = true }) {
                            Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.detail_action_delete))
                        }
                    }
                }
            )
        }
    ) { padding ->
        val current = restaurant
        if (current != null) {
            Column(modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
                Text(current.cuisineType, style = MaterialTheme.typography.bodyLarge)
                current.address?.let { Text(it, style = MaterialTheme.typography.bodyLarge) }

                Row(modifier = Modifier.padding(top = 8.dp)) {
                    repeat(current.rating) {
                        Icon(Icons.Default.Star, contentDescription = null)
                    }
                }

                Text("$".repeat(current.priceRange), modifier = Modifier.padding(top = 8.dp))
                Text(
                    current.visitDate.format(DateTimeFormatter.ISO_LOCAL_DATE),
                    modifier = Modifier.padding(top = 8.dp)
                )

                if (current.notes.isNotBlank()) {
                    Text(current.notes, modifier = Modifier.padding(top = 16.dp))
                }
            }
        }
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text(stringResource(R.string.detail_delete_confirm_title)) },
            text = { Text(stringResource(R.string.detail_delete_confirm_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirm = false
                    viewModel.delete(onDeleted)
                }) { Text(stringResource(R.string.detail_delete_confirm_ok)) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) {
                    Text(stringResource(R.string.detail_delete_confirm_cancel))
                }
            }
        )
    }
}
