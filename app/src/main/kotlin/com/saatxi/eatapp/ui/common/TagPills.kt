package com.saatxi.eatapp.ui.common

import android.content.res.Configuration
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.saatxi.eatapp.ui.theme.EatAppTheme

/**
 * Small pill badges for free-form tags (F-59), reused by the list row, the
 * detail screen and the import review row so the three don't drift. Uses the
 * same pill shape [RestaurantRow][com.saatxi.eatapp.ui.list.RestaurantRow]
 * already draws for its "want to try" badge.
 *
 * [maxVisible] caps how many pills draw before collapsing the rest into one
 * "+N" pill — the list row passes this to keep row heights predictable
 * across restaurants with wildly different tag counts; the detail and import
 * screens pass null (unbounded), since neither is a scrolling list of many
 * same-shaped rows.
 */
@Composable
internal fun TagPillRow(tags: List<String>, modifier: Modifier = Modifier, maxVisible: Int? = null) {
    if (tags.isEmpty()) return

    val visibleTags = maxVisible?.let { tags.take(it) } ?: tags
    val overflowCount = tags.size - visibleTags.size

    FlowRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        visibleTags.forEach { tag -> TagPill(text = tag) }
        if (overflowCount > 0) TagPill(text = "+$overflowCount")
    }
}

@Composable
private fun TagPill(text: String) {
    Surface(shape = RoundedCornerShape(percent = 50), color = MaterialTheme.colorScheme.secondaryContainer) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSecondaryContainer,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
        )
    }
}

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun TagPillRowPreview() {
    EatAppTheme {
        Surface {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                TagPillRow(tags = listOf("Terraza", "Para grupos", "Llevar niños"))
                TagPillRow(tags = listOf("Terraza", "Para grupos", "Llevar niños", "Brunch", "Vegano"), maxVisible = 3)
            }
        }
    }
}
