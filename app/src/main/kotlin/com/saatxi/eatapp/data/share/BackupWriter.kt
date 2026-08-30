package com.saatxi.eatapp.data.share

import android.content.Context
import java.io.File
import kotlinx.serialization.json.Json

private val json = Json
private const val BACKUP_FILE_NAME = "backup.json"

/**
 * Writes [restaurants] to `backup.json` under the app's private `filesDir` —
 * unlike [writeRestaurantShareFile], never under `cacheDir` and never exposed
 * through the FileProvider — so Android's own Auto Backup / cloud backup
 * (already covering all of `filesDir`, see `res/xml/backup_rules.xml`) always
 * has a full, current snapshot without the user needing to press "share".
 */
fun writeBackupFile(context: Context, restaurants: List<RestaurantExport>) {
    val text = json.encodeToString(RestaurantShareFile.serializer(), RestaurantShareFile(restaurants = restaurants))
    File(context.filesDir, BACKUP_FILE_NAME).writeText(text)
}
