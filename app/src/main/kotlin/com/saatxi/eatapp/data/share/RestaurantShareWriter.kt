package com.saatxi.eatapp.data.share

import android.content.Context
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.serialization.json.Json

private val json = Json { encodeDefaults = true }
private const val SHARE_SUBDIR = "shared"

/** e.g. `restaurants-20260913_1742.eatapp`, timestamped so re-sharing later doesn't overwrite a file the recipient already saved under the same name. */
private fun shareFileName(now: Date = Date()): String =
    "restaurants-${SimpleDateFormat("yyyyMMdd_HHmm", Locale.US).format(now)}.eatapp"

/**
 * Writes [restaurants] to a timestamped file under `cacheDir/shared/` — the
 * only subdirectory `res/xml/file_paths.xml` exposes through the
 * FileProvider — and returns a `content://` Uri another app can be granted
 * read access to. Any share file left over from a previous call is deleted
 * first, so `cacheDir/shared/` never accumulates one file per share.
 */
fun writeRestaurantShareFile(context: Context, restaurants: List<RestaurantExport>): Uri {
    val text = json.encodeToString(RestaurantShareFile.serializer(), RestaurantShareFile(restaurants = restaurants))

    val dir = File(context.cacheDir, SHARE_SUBDIR).apply { mkdirs() }
    dir.listFiles()?.forEach { it.delete() }
    val file = File(dir, shareFileName())
    file.writeText(text)

    return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
}
