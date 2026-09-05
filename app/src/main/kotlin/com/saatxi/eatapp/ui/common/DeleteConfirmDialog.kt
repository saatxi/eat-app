package com.saatxi.eatapp.ui.common

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.saatxi.eatapp.R

/**
 * The confirmation shown before an irreversible delete — shared by the
 * detail screen's trash icon and the list/favourites rows' swipe-to-delete
 * gesture (F-65), so the wording and button layout for the same destructive
 * action can't drift between its two entry points.
 */
@Composable
internal fun DeleteConfirmDialog(onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.detail_delete_confirm_title)) },
        text = { Text(stringResource(R.string.detail_delete_confirm_body)) },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(stringResource(R.string.action_delete))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.action_cancel))
            }
        }
    )
}
