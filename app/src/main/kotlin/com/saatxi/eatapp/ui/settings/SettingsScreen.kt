package com.saatxi.eatapp.ui.settings

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.automirrored.outlined.HelpOutline
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import com.saatxi.eatapp.BuildConfig
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.common.ExportOptionsDialog
import com.saatxi.eatapp.ui.common.IconLabelRow
import com.saatxi.eatapp.ui.common.findActivity
import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.EatAppTheme
import com.saatxi.eatapp.ui.theme.ThemeMode
import com.saatxi.eatapp.ui.theme.darkScheme
import com.saatxi.eatapp.ui.theme.isDarkTheme
import com.saatxi.eatapp.ui.theme.lightScheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onOpenStatistics: () -> Unit = {},
    onOpenHelp: () -> Unit = {},
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    var showDeleteAllConfirm by remember { mutableStateOf(false) }
    var showExportDialog by remember { mutableStateOf(false) }

    if (showDeleteAllConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteAllConfirm = false },
            title = { Text(stringResource(R.string.settings_delete_all_confirm_title)) },
            text = { Text(stringResource(R.string.settings_delete_all_confirm_body)) },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteAllConfirm = false
                    viewModel.onDeleteAllData()
                }) {
                    Text(stringResource(R.string.action_delete))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteAllConfirm = false }) {
                    Text(stringResource(R.string.action_cancel))
                }
            }
        )
    }

    if (showExportDialog) {
        ExportOptionsDialog(
            onConfirm = { includeVisits ->
                showExportDialog = false
                viewModel.onExportData(context, includeVisits)
            },
            onDismiss = { showExportDialog = false }
        )
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text(stringResource(R.string.settings_title)) }) }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Every section's content now sits in a Card (F-78) — the same language
            // Detail and the edit form already use — rather than a flat list of
            // controls with only a coloured label to separate them.
            SettingsSection(title = stringResource(R.string.settings_section_appearance)) {
                Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.settings_palette), style = MaterialTheme.typography.labelLarge)
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(20.dp),
                            modifier = Modifier.padding(top = 12.dp)
                        ) {
                            // Resolved against the mode actually in effect (not the raw system
                            // setting), so a swatch previews what picking that palette will
                            // really look like right now.
                            val darkTheme = isDarkTheme(uiState.themeMode)
                            AppPalette.entries.forEach { palette ->
                                PaletteSwatch(
                                    palette = palette,
                                    darkTheme = darkTheme,
                                    selected = palette == uiState.palette,
                                    onClick = { viewModel.onPaletteChange(palette) }
                                )
                            }
                        }

                        Text(
                            text = stringResource(R.string.settings_theme_mode),
                            style = MaterialTheme.typography.labelLarge,
                            modifier = Modifier.padding(top = 20.dp)
                        )
                        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                            ThemeMode.entries.forEachIndexed { index, mode ->
                                SegmentedButton(
                                    selected = mode == uiState.themeMode,
                                    onClick = { viewModel.onThemeModeChange(mode) },
                                    shape = SegmentedButtonDefaults.itemShape(index = index, count = ThemeMode.entries.size),
                                    // The default checkmark eats into this row's three-way split
                                    // and clips a longer translation — the fill colour already
                                    // marks the selection.
                                    icon = {}
                                ) {
                                    Text(stringResource(mode.labelRes))
                                }
                            }
                        }
                    }
                }
            }

            SettingsSection(title = stringResource(R.string.settings_section_language)) {
                var languageMenuExpanded by remember { mutableStateOf(false) }
                Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
                    Box {
                        SettingsRow(
                            icon = Icons.Outlined.Language,
                            label = stringResource(uiState.language.labelRes),
                            showChevron = false,
                            onClick = { languageMenuExpanded = true }
                        )
                        DropdownMenu(
                            expanded = languageMenuExpanded,
                            onDismissRequest = { languageMenuExpanded = false }
                        ) {
                            AppLanguage.entries.forEach { language ->
                                DropdownMenuItem(
                                    text = { Text(stringResource(language.labelRes)) },
                                    onClick = {
                                        languageMenuExpanded = false
                                        viewModel.onLanguageChange(language)
                                        // AppCompatDelegate applies the new locale to the
                                        // process, but MainActivity only picks it up once
                                        // it is recreated — the framework does this for us
                                        // on API 33+, but some OEM builds don't reliably
                                        // deliver that config change, so trigger it
                                        // explicitly rather than rely on it.
                                        activity?.recreate()
                                    },
                                    trailingIcon = if (language == uiState.language) {
                                        { Icon(Icons.Default.Check, contentDescription = null) }
                                    } else null
                                )
                            }
                        }
                    }
                }
            }

            SettingsSection(title = stringResource(R.string.settings_section_data)) {
                Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
                    Column {
                        SettingsRow(
                            icon = Icons.Outlined.BarChart,
                            label = stringResource(R.string.settings_action_view_statistics),
                            onClick = onOpenStatistics
                        )
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                        SettingsRow(
                            icon = Icons.Filled.Share,
                            label = stringResource(R.string.settings_action_export_data),
                            showChevron = false,
                            onClick = { showExportDialog = true }
                        )
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                        SettingsRow(
                            icon = Icons.Filled.Delete,
                            label = stringResource(R.string.settings_action_delete_all_data),
                            showChevron = false,
                            tint = MaterialTheme.colorScheme.error,
                            onClick = { showDeleteAllConfirm = true }
                        )
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                        SettingsRow(
                            icon = Icons.AutoMirrored.Outlined.HelpOutline,
                            label = stringResource(R.string.settings_action_help),
                            onClick = onOpenHelp
                        )
                    }
                }
            }

            SettingsSection(title = stringResource(R.string.settings_section_about)) {
                Card(shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
                    SettingsRow(
                        icon = Icons.Outlined.Info,
                        // A clean build (no local changes on top of a committed tree) just
                        // shows the bare "X.Y.Z" a user would recognise from a release note
                        // — the build number and commit hash only earn their place once the
                        // build doesn't match a plain committed state ("-dirty" from git
                        // describe), where they're what actually tells two dev builds apart.
                        label = if (BuildConfig.VERSION_NAME.endsWith("-dirty")) {
                            stringResource(
                                R.string.about_version_template,
                                BuildConfig.VERSION_NAME,
                                BuildConfig.VERSION_CODE,
                                BuildConfig.GIT_COMMIT
                            )
                        } else {
                            stringResource(R.string.about_version_template_clean, BuildConfig.VERSION_NAME.substringBefore("-"))
                        },
                        showChevron = false,
                        onClick = null
                    )
                }
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
        Column(modifier = Modifier.padding(top = 8.dp), content = content)
    }
}

/**
 * The icon-plus-label-plus-trailing-chevron row every settings section now
 * shares (F-78) — "export data" used to be a lost `OutlinedButton`; this is
 * what makes it read as an actual settings row instead. [showChevron] is
 * false for a row that isn't navigation (an in-place action instead).
 */
@Composable
private fun SettingsRow(
    icon: ImageVector,
    label: String,
    modifier: Modifier = Modifier,
    showChevron: Boolean = true,
    tint: Color = MaterialTheme.colorScheme.onSurface,
    onClick: (() -> Unit)?
) {
    IconLabelRow(
        modifier = modifier
            .fillMaxWidth()
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        contentPadding = PaddingValues(start = 16.dp),
        leading = { Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(22.dp)) },
        trailing = if (showChevron) {
            {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp)
                )
            }
        } else {
            null
        }
    ) {
        Text(text = label, style = MaterialTheme.typography.bodyLarge, color = tint)
    }
}

/** Grown from 26dp to 30dp (F-78) — the one screen element that already had some charm. */
private val PALETTE_SWATCH_SIZE = 30.dp

@Composable
private fun PaletteSwatch(
    palette: AppPalette,
    darkTheme: Boolean,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    // The tones a palette declares, not the currently active MaterialTheme, so
    // all three swatches preview correctly even though only one of them is the
    // scheme actually applied to the screen right now.
    val scheme = remember(palette, darkTheme) {
        if (darkTheme) palette.tones.darkScheme() else palette.tones.lightScheme()
    }
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier.clickable(onClick = onClick).padding(4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(PALETTE_SWATCH_SIZE)
                // A soft halo in the palette's own primary colour (F-78) rather than a
                // hard-edged border, on top of the three-colour sweep that stands in for
                // the whole scheme in one small circle. Colored ambient/spot shadows only
                // render from API 28 onward (minSdk is 26); below that the platform falls
                // back to a plain gray shadow, and the border below is what still marks
                // selection unambiguously there (F-83, accepted as-is: not worth an
                // SDK-gated fallback path for a purely cosmetic difference).
                .let {
                    if (selected) {
                        it.shadow(elevation = 6.dp, shape = CircleShape, ambientColor = scheme.primary, spotColor = scheme.primary)
                    } else {
                        it
                    }
                }
                .clip(CircleShape)
                .background(Brush.sweepGradient(listOf(scheme.primary, scheme.secondary, scheme.tertiary, scheme.primary)))
                .let { if (selected) it.border(2.dp, scheme.primary, CircleShape) else it }
        )
        Text(
            text = stringResource(palette.labelRes),
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(top = 6.dp)
        )
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun PaletteSwatchPreview() {
    EatAppTheme {
        Surface {
            Row(horizontalArrangement = Arrangement.spacedBy(20.dp), modifier = Modifier.padding(16.dp)) {
                AppPalette.entries.forEach { palette ->
                    PaletteSwatch(
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
