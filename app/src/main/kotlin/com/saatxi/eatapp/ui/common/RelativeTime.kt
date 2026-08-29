package com.saatxi.eatapp.ui.common

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import com.saatxi.eatapp.R

private const val MINUTE_MS = 60_000L
private const val HOUR_MS = 3_600_000L
private const val DAY_MS = 86_400_000L

/**
 * "just now" / "5 minutes ago" / "2 days ago".
 *
 * Resolved at draw time rather than formatted into the state, so the phrasing
 * follows the device locale and the plural rules of the active language.
 */
@Composable
fun formatRelativeTime(timestampMs: Long): String {
    val diff = System.currentTimeMillis() - timestampMs
    return when {
        diff < MINUTE_MS -> stringResource(R.string.relative_time_just_now)
        diff < HOUR_MS -> {
            val minutes = (diff / MINUTE_MS).toInt()
            pluralStringResource(R.plurals.relative_time_minutes_ago, minutes, minutes)
        }
        diff < DAY_MS -> {
            val hours = (diff / HOUR_MS).toInt()
            pluralStringResource(R.plurals.relative_time_hours_ago, hours, hours)
        }
        else -> {
            val days = (diff / DAY_MS).toInt()
            pluralStringResource(R.plurals.relative_time_days_ago, days, days)
        }
    }
}
