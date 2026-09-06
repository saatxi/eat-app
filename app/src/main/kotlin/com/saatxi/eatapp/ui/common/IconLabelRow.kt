package com.saatxi.eatapp.ui.common

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * The icon/badge, then a weighted label column, then optional trailing content
 * skeleton `SettingsRow` and `RestaurantRow` each built separately — pulled out
 * once (F-87) so a future tweak to that shared shape can't silently drift
 * between Settings and List/Favorites the way it had no compiler check to stay
 * in sync before. [contentPadding] is a parameter rather than a fixed value
 * because the two call sites don't want quite the same gap: Settings only
 * pads the label column's start (a chevron, when present, sits flush against
 * the row's own edge), while List pads both sides (its trailing content is a
 * rating/price column, not the row's edge).
 */
@Composable
internal fun IconLabelRow(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp),
    leading: @Composable () -> Unit,
    trailing: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Row(modifier = modifier, verticalAlignment = Alignment.CenterVertically) {
        leading()
        Column(modifier = Modifier.weight(1f).padding(contentPadding), content = content)
        trailing?.invoke()
    }
}
