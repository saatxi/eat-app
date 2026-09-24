package com.saatxi.eatapp.ui.common

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.saatxi.eatapp.R

/**
 * The "what goes in the file?" step shown before any share or export — one
 * restaurant from the detail screen, the whole list from "share all", or the
 * settings "export my data" row. All three want the same decision (whether to
 * carry visits along), so they share one dialog rather than three hand-rolled
 * variants whose wording could drift.
 *
 * "Include visits" defaults to on: visits are the user's own history and the
 * whole point of a backup, so the safe default is to keep them — turning the
 * switch off is the deliberate opt-out. [onConfirm] receives the chosen value.
 */
@Composable
fun ExportOptionsDialog(
    onConfirm: (includeVisits: Boolean) -> Unit,
    onDismiss: () -> Unit
) {
    var includeVisits by remember { mutableStateOf(true) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.export_dialog_title)) },
        text = {
            Column {
                Text(stringResource(R.string.export_dialog_body))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 12.dp)
                ) {
                    Switch(checked = includeVisits, onCheckedChange = { includeVisits = it })
                    Text(
                        text = stringResource(R.string.export_dialog_include_visits),
                        modifier = Modifier.padding(start = 12.dp)
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(includeVisits) }) {
                Text(stringResource(R.string.action_export))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.action_cancel))
            }
        }
    )
}
