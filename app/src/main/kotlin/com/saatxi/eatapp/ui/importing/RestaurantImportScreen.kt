package com.saatxi.eatapp.ui.importing

import android.content.res.Configuration
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.RestaurantMenu
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.saatxi.eatapp.R
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.share.ImportFailureReason
import com.saatxi.eatapp.ui.AppViewModelProvider
import com.saatxi.eatapp.ui.common.cuisineLabel
import com.saatxi.eatapp.ui.list.EmptyState
import com.saatxi.eatapp.ui.theme.EatAppTheme

@Composable
fun RestaurantImportScreen(
    uri: Uri,
    onDone: () -> Unit,
    viewModel: RestaurantImportViewModel = viewModel(
        key = "import-$uri",
        factory = AppViewModelProvider.importViewModelFactory(uri)
    )
) {
    val uiState by viewModel.uiState.collectAsState()
    RestaurantImportContent(
        uiState = uiState,
        onDone = onDone,
        onDecisionChange = viewModel::onDecisionChange,
        onConfirm = { viewModel.onConfirm(onDone) }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RestaurantImportContent(
    uiState: RestaurantImportUiState,
    onDone: () -> Unit,
    onDecisionChange: (Int, ImportDecision) -> Unit,
    onConfirm: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.import_title)) },
                navigationIcon = {
                    IconButton(onClick = onDone) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.action_back))
                    }
                }
            )
        }
    ) { padding ->
        when {
            uiState.isLoading -> Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }

            uiState.error != null -> EmptyState(
                icon = Icons.Outlined.ErrorOutline,
                title = stringResource(R.string.import_error_title),
                body = stringResource(importErrorBodyRes(uiState.error)),
                actionLabel = stringResource(R.string.action_ok),
                onAction = onDone,
                modifier = Modifier.fillMaxSize().padding(padding)
            )

            uiState.candidates.isEmpty() -> EmptyState(
                icon = Icons.Outlined.RestaurantMenu,
                title = stringResource(R.string.import_empty_title),
                body = stringResource(R.string.import_empty_body),
                actionLabel = stringResource(R.string.action_ok),
                onAction = onDone,
                modifier = Modifier.fillMaxSize().padding(padding)
            )

            else -> Column(modifier = Modifier.fillMaxSize().padding(padding)) {
                if (uiState.skippedInvalidCount > 0) {
                    Text(
                        text = pluralStringResource(
                            R.plurals.import_skipped_invalid,
                            uiState.skippedInvalidCount,
                            uiState.skippedInvalidCount
                        ),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(16.dp)
                    )
                }
                LazyColumn(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    itemsIndexed(uiState.candidates) { index, candidate ->
                        ImportCandidateRow(
                            candidate = candidate,
                            onDecisionChange = { decision -> onDecisionChange(index, decision) }
                        )
                    }
                }
                Button(
                    onClick = onConfirm,
                    enabled = !uiState.isImporting,
                    modifier = Modifier.fillMaxWidth().padding(16.dp)
                ) {
                    Text(stringResource(R.string.import_action_confirm))
                }
            }
        }
    }
}

private fun importErrorBodyRes(reason: ImportFailureReason): Int = when (reason) {
    ImportFailureReason.TOO_LARGE -> R.string.import_error_too_large
    ImportFailureReason.INVALID_FILE -> R.string.import_error_invalid
    ImportFailureReason.IO_ERROR -> R.string.import_error_io
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ImportCandidateRow(
    candidate: ImportCandidate,
    onDecisionChange: (ImportDecision) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = candidate.restaurant.name, style = MaterialTheme.typography.titleMedium)
            Text(
                text = cuisineLabel(candidate.restaurant.cuisineType),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            candidate.restaurant.address?.let { address ->
                Text(
                    text = address,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            if (candidate.duplicateOf != null) {
                Text(
                    text = stringResource(R.string.import_duplicate_label),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }

            val options = if (candidate.duplicateOf != null) {
                listOf(ImportDecision.SKIP, ImportDecision.ADD, ImportDecision.REPLACE)
            } else {
                listOf(ImportDecision.SKIP, ImportDecision.ADD)
            }
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                options.forEachIndexed { index, option ->
                    SegmentedButton(
                        selected = candidate.decision == option,
                        onClick = { onDecisionChange(option) },
                        shape = SegmentedButtonDefaults.itemShape(index = index, count = options.size)
                    ) {
                        Text(importDecisionLabel(option))
                    }
                }
            }
        }
    }
}

@Composable
private fun importDecisionLabel(decision: ImportDecision): String = when (decision) {
    ImportDecision.ADD -> stringResource(R.string.import_decision_add)
    ImportDecision.SKIP -> stringResource(R.string.import_decision_skip)
    ImportDecision.REPLACE -> stringResource(R.string.import_decision_replace)
}

private val previewCandidate = ImportCandidate(
    restaurant = Restaurant(
        id = 0,
        name = "Cal Ferran",
        cuisineType = "mediterranean",
        address = "Plaça Santa Anna, Mataró",
        rating = 4,
        priceRange = 2
    ),
    duplicateOf = null,
    decision = ImportDecision.ADD
)

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RestaurantImportScreenPreview() {
    EatAppTheme {
        Surface {
            RestaurantImportContent(
                uiState = RestaurantImportUiState(isLoading = false, candidates = listOf(previewCandidate)),
                onDone = {},
                onDecisionChange = { _, _ -> },
                onConfirm = {}
            )
        }
    }
}
