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

/** Longest a restaurant's name is allowed to grow in a filename — long enough to stay recognisable, short enough to stay portable. */
private const val MAX_NAME_SLUG_LENGTH = 60

/** Used when a name is blank or nothing survives sanitising — a file still needs *some* name. */
private const val FALLBACK_SLUG = "restaurant"

/**
 * Turns a restaurant name into a filesystem-safe slug: anything that isn't a
 * letter or a digit (spaces, punctuation, path separators) folds to a single
 * `-`, runs collapse, and the result is capped so one long name can't produce
 * an unwieldy filename. Letters keep their accents — a filename is UTF-8, and
 * stripping them would make `Cafè` unreachable from `Cafe`.
 */
internal fun restaurantNameSlug(name: String): String {
    // Locale.ROOT, not the default locale: `lowercase()` under a Turkish
    // locale would turn "I" into "ı", making the filename depend on the
    // device's language.
    val slug = name.trim().lowercase(Locale.ROOT)
        .replace(Regex("[^\\p{L}\\p{N}]+"), "-")
        .take(MAX_NAME_SLUG_LENGTH)
        .trim('-')
    return slug.ifEmpty { FALLBACK_SLUG }
}

/**
 * e.g. `restaurants-20260913_1742.eatapp` for a bulk export, or
 * `cal-ferran-20260913_1742.eatapp` when sharing a single restaurant. The
 * timestamp is kept either way so re-sharing later doesn't overwrite a file
 * the recipient already saved under the same name.
 */
private fun shareFileName(singleName: String? = null, now: Date = Date()): String {
    val base = singleName?.let(::restaurantNameSlug) ?: "restaurants"
    return "$base-${SimpleDateFormat("yyyyMMdd_HHmm", Locale.US).format(now)}.eatapp"
}

/**
 * Writes [restaurants] to a timestamped file under `cacheDir/shared/` — the
 * only subdirectory `res/xml/file_paths.xml` exposes through the
 * FileProvider — and returns a `content://` Uri another app can be granted
 * read access to. Any share file left over from a previous call is deleted
 * first, so `cacheDir/shared/` never accumulates one file per share.
 *
 * [singleName], when non-null, is the one restaurant in [restaurants] and is
 * folded into the filename so a shared single restaurant arrives named after
 * itself rather than as a generic "restaurants" file.
 */
fun writeRestaurantShareFile(context: Context, restaurants: List<RestaurantExport>, singleName: String? = null): Uri {
    val text = json.encodeToString(RestaurantShareFile.serializer(), RestaurantShareFile(restaurants = restaurants))

    val dir = File(context.cacheDir, SHARE_SUBDIR).apply { mkdirs() }
    dir.listFiles()?.forEach { it.delete() }
    val file = File(dir, shareFileName(singleName))
    file.writeText(text)

    return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
}
