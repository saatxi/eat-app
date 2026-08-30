package com.saatxi.eatapp.data.share

import android.content.Context
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import kotlinx.serialization.json.Json

private val json = Json
private const val SHARE_SUBDIR = "shared"
private const val SHARE_FILE_NAME = "restaurants.json"

/**
 * Writes [restaurants] to a file under `cacheDir/shared/` — the only
 * subdirectory `res/xml/file_paths.xml` exposes through the FileProvider —
 * and returns a `content://` Uri another app can be granted read access to.
 */
fun writeRestaurantShareFile(context: Context, restaurants: List<RestaurantExport>): Uri {
    val text = json.encodeToString(RestaurantShareFile.serializer(), RestaurantShareFile(restaurants = restaurants))

    val dir = File(context.cacheDir, SHARE_SUBDIR).apply { mkdirs() }
    val file = File(dir, SHARE_FILE_NAME)
    file.writeText(text)

    return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
}
