package com.saatxi.eatapp.ui.common

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp

/**
 * A single-value text field that suggests values already used elsewhere in the user's own data
 * (e.g. a town typed on a previous restaurant) without ever forcing a pick — any typed text is
 * valid, unlike a closed-vocabulary dropdown such as [com.saatxi.eatapp.data.local.Cuisine]'s.
 *
 * Structurally the single-value counterpart of the edit form's own `TagsField`: same
 * "suggestion row below the field, tap to fill" idea, minus the chip-list/multi-value machinery,
 * since there's only ever one value here.
 */
@Composable
fun AutocompleteTextField(
    value: String,
    onValueChange: (String) -> Unit,
    suggestions: List<String>,
    label: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    keyboardOptions: KeyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words)
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = label,
        singleLine = true,
        keyboardOptions = keyboardOptions,
        modifier = modifier.fillMaxWidth()
    )

    val matchingSuggestions = if (value.isBlank()) {
        emptyList()
    } else {
        suggestions.filter { it.contains(value, ignoreCase = true) && !it.equals(value, ignoreCase = true) }
    }
    if (matchingSuggestions.isNotEmpty()) {
        val chipColors = FilterChipDefaults.filterChipColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant,
            labelColor = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(top = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            matchingSuggestions.forEach { suggestion ->
                FilterChip(
                    selected = false,
                    onClick = { onValueChange(suggestion) },
                    label = { Text(suggestion) },
                    colors = chipColors
                )
            }
        }
    }
}
