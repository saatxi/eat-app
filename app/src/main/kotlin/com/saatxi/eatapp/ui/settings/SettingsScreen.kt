package com.saatxi.eatapp.ui.settings

import android.content.res.Configuration
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.saatxi.eatapp.BuildConfig
import com.saatxi.eatapp.R
import com.saatxi.eatapp.data.sync.RestaurantDatabaseSyncManager
import com.saatxi.eatapp.data.sync.SyncFailureReason
import com.saatxi.eatapp.ui.AppViewModelProvider
import com.saatxi.eatapp.ui.common.formatRelativeTime
import com.saatxi.eatapp.ui.list.SyncMessage
import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.EatAppTheme
import com.saatxi.eatapp.ui.theme.ThemeMode
import com.saatxi.eatapp.ui.theme.darkScheme
import com.saatxi.eatapp.ui.theme.isDarkTheme
import com.saatxi.eatapp.ui.theme.lightScheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val snackbarHostState = remember { SnackbarHostState() }

    val syncErrorNetwork = stringResource(R.string.list_sync_error_network)
    val syncErrorInvalid = stringResource(R.string.list_sync_error_invalid)
    val syncErrorUnknown = stringResource(R.string.list_sync_error_unknown)
    val syncUpToDate = stringResource(R.string.list_sync_up_to_date)
    val retryLabel = stringResource(R.string.action_retry)

    // Resolved here rather than inside the LaunchedEffect below, because
    // pluralStringResource (like stringResource) is a @Composable function and
    // LaunchedEffect's block is a plain suspend lambda, not a composable one.
    val pendingSyncMessage = uiState.pendingSyncMessage
    val pendingSyncMessageText = when (pendingSyncMessage) {
        is SyncMessage.Success ->
            pluralStringResource(R.plurals.list_sync_success, pendingSyncMessage.count, pendingSyncMessage.count)
        SyncMessage.UpToDate -> syncUpToDate
        is SyncMessage.Error -> when (pendingSyncMessage.reason) {
            SyncFailureReason.NETWORK -> syncErrorNetwork
            SyncFailureReason.INVALID_FILE -> syncErrorInvalid
            SyncFailureReason.IO_ERROR, SyncFailureReason.UNKNOWN -> syncErrorUnknown
        }
        null -> null
    }

    // Same pattern as the list screen's sync feedback: carried in the state
    // rather than a one-shot event, so it survives a config change.
    LaunchedEffect(pendingSyncMessage) {
        val message = pendingSyncMessage ?: return@LaunchedEffect
        val text = pendingSyncMessageText ?: return@LaunchedEffect
        val actionLabel = if (message is SyncMessage.Error) retryLabel else null
        val result = snackbarHostState.showSnackbar(text, actionLabel = actionLabel)
        if (result == SnackbarResult.ActionPerformed) {
            viewModel.syncNow()
        }
        viewModel.onSyncMessageShown()
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text(stringResource(R.string.settings_title)) }) },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            SettingsSection(title = stringResource(R.string.settings_section_appearance)) {
                Text(stringResource(R.string.settings_palette), style = MaterialTheme.typography.labelLarge)
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                ) {
                    // Resolved against the mode actually in effect (not the raw system
                    // setting), so a swatch previews what picking that palette will
                    // really look like right now.
                    val darkTheme = isDarkTheme(uiState.themeMode)
                    AppPalette.entries.forEach { palette ->
                        PaletteCard(
                            palette = palette,
                            darkTheme = darkTheme,
                            selected = palette == uiState.palette,
                            onClick = { viewModel.onPaletteChange(palette) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                Text(
                    text = stringResource(R.string.settings_theme_mode),
                    style = MaterialTheme.typography.labelLarge,
                    modifier = Modifier.padding(top = 16.dp)
                )
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                    ThemeMode.entries.forEachIndexed { index, mode ->
                        SegmentedButton(
                            selected = mode == uiState.themeMode,
                            onClick = { viewModel.onThemeModeChange(mode) },
                            shape = SegmentedButtonDefaults.itemShape(index = index, count = ThemeMode.entries.size)
                        ) {
                            Text(stringResource(mode.labelRes))
                        }
                    }
                }
            }

            SettingsSection(title = stringResource(R.string.settings_section_data)) {
                val lastSyncTime = RestaurantDatabaseSyncManager.getLastSyncTime(context)
                val lastSyncText = if (lastSyncTime > 0) {
                    stringResource(R.string.about_last_synced, formatRelativeTime(lastSyncTime))
                } else {
                    stringResource(R.string.about_last_synced_never)
                }
                Text(text = lastSyncText, style = MaterialTheme.typography.bodyMedium)
                Button(
                    onClick = viewModel::syncNow,
                    enabled = !uiState.isSyncing,
                    modifier = Modifier.padding(top = 8.dp)
                ) {
                    Text(stringResource(R.string.list_action_sync))
                }
            }

            SettingsSection(title = stringResource(R.string.settings_section_about)) {
                Text(
                    text = stringResource(
                        R.string.about_version_template,
                        BuildConfig.VERSION_NAME,
                        BuildConfig.VERSION_CODE,
                        BuildConfig.GIT_COMMIT
                    ),
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.primary
        )
        Column(content = content)
    }
}

@Composable
private fun PaletteCard(
    palette: AppPalette,
    darkTheme: Boolean,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    // The tones a palette declares, not the currently active MaterialTheme, so
    // all three cards preview correctly even though only one of them is the
    // scheme actually applied to the screen right now.
    val scheme = remember(palette, darkTheme) {
        if (darkTheme) palette.tones.darkScheme() else palette.tones.lightScheme()
    }
    Card(
        onClick = onClick,
        modifier = modifier,
        border = if (selected) BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth().padding(12.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                listOf(scheme.primary, scheme.secondary, scheme.tertiary).forEach { color ->
                    Box(
                        modifier = Modifier
                            .size(20.dp)
                            .clip(CircleShape)
                            .background(color)
                    )
                }
            }
            Text(
                text = stringResource(palette.labelRes),
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.padding(top = 8.dp)
            )
        }
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun PaletteCardPreview() {
    EatAppTheme {
        Surface {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(16.dp)) {
                AppPalette.entries.forEach { palette ->
                    PaletteCard(
                        palette = palette,
                        darkTheme = false,
                        selected = palette == AppPalette.Default,
                        onClick = {}
                    )
                }
            }
        }
    }
}
