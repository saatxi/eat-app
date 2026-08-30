package com.saatxi.eatapp.data.share

import com.saatxi.eatapp.data.local.Restaurant
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

/** A file bigger than this is rejected before it's even parsed. */
const val MAX_IMPORT_BYTES = 5L * 1024 * 1024

enum class ImportFailureReason { TOO_LARGE, INVALID_FILE, IO_ERROR }

sealed interface ImportOutcome {
    /**
     * [skippedCount] is how many rows failed per-row validation and were
     * dropped rather than failing the whole file — see [toRestaurantOrNull].
     */
    data class Success(val restaurants: List<Restaurant>, val skippedCount: Int) : ImportOutcome
    data class Error(val reason: ImportFailureReason) : ImportOutcome
}

private val json = Json { ignoreUnknownKeys = true }

/**
 * Parses and validates a share file already read into memory. Deliberately
 * free of Android imports — the file's *contents* are untrusted the same way
 * the old synced `.db` was, and the same rule applies: validate every field
 * before anything reaches Room. Fetching the bytes off a `content://` Uri is
 * a separate, Android-only step; see `ContentFiles.kt`.
 */
object RestaurantImportReader {

    fun read(rawJson: String): ImportOutcome {
        val shareFile = try {
            json.decodeFromString(RestaurantShareFile.serializer(), rawJson)
        } catch (e: SerializationException) {
            return ImportOutcome.Error(ImportFailureReason.INVALID_FILE)
        } catch (e: IllegalArgumentException) {
            return ImportOutcome.Error(ImportFailureReason.INVALID_FILE)
        }

        if (shareFile.format != RestaurantShareFile.FORMAT) {
            return ImportOutcome.Error(ImportFailureReason.INVALID_FILE)
        }

        val restaurants = shareFile.restaurants.mapNotNull { it.toRestaurantOrNull() }
        val skippedCount = shareFile.restaurants.size - restaurants.size
        return ImportOutcome.Success(restaurants, skippedCount)
    }
}
