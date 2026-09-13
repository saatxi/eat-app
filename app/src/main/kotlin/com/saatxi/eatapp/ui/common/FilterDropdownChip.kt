package com.saatxi.eatapp.ui.common

import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.SelectableChipColors
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier

/**
 * A single filter dimension collapsed into one chip: tapping it opens a
 * [DropdownMenu] listing [options] (each responsible for calling the
 * `closeMenu` callback it's given once the user picks something). Used to
 * keep a screen's filter row to one line instead of one chip per option
 * wrapping across several.
 */
@Composable
fun FilterDropdownChip(
    selectedLabel: String,
    isActive: Boolean,
    colors: SelectableChipColors,
    modifier: Modifier = Modifier,
    leadingIcon: @Composable (() -> Unit)? = null,
    options: @Composable (closeMenu: () -> Unit) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    Box(modifier = modifier) {
        FilterChip(
            selected = isActive,
            onClick = { expanded = true },
            label = { Text(selectedLabel) },
            leadingIcon = leadingIcon,
            trailingIcon = { Icon(Icons.Filled.ArrowDropDown, contentDescription = null) },
            colors = colors
        )
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options { expanded = false }
        }
    }
}
