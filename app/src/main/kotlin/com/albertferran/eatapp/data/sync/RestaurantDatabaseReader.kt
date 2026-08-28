package com.albertferran.eatapp.data.sync

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import android.util.Log
import com.albertferran.eatapp.data.local.Restaurant
import java.io.File
import java.io.IOException

internal val REQUIRED_COLUMNS = setOf(
    "id", "name", "cuisineType", "address", "rating", "priceRange"
)

/**
 * Columns a newer data file may carry. Deliberately not in [REQUIRED_COLUMNS]:
 * a file written before these existed — including the one currently published —
 * has to keep validating, or upgrading the app would empty it.
 */
internal val OPTIONAL_COLUMNS = listOf("website", "instagram")

/**
 * [REQUIRED_COLUMNS] in the order the row reader indexes them. A set has no
 * order, and the cursor is read positionally, so the two can't be the same value.
 */
private val REQUIRED_COLUMN_ORDER =
    listOf("id", "name", "cuisineType", "address", "rating", "priceRange")

private const val TAG = "EatApp.Sync"

/** The 16-byte prefix every SQLite file begins with, terminating NUL included. */
private val SQLITE_HEADER = "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII)

internal sealed interface ReadOutcome {
    data class Rows(val restaurants: List<Restaurant>) : ReadOutcome
    data class Error(val failure: DatabaseSyncResult.Failure) : ReadOutcome
}

/**
 * Reads and validates a downloaded `.db`.
 *
 * Kept separate from the download so the validation rules — the ones standing
 * between a hand-edited data file and a crash — can be exercised against a
 * file directly, without a network round trip.
 *
 * The file is untrusted input: it is opened read-only and every row is checked
 * before anything reaches the local database.
 */
internal object RestaurantDatabaseReader {

    fun read(file: File): ReadOutcome {
        var db: SQLiteDatabase? = null
        return try {
            // Cheaper than handing arbitrary bytes to SQLite, and it turns what
            // would be a generic SQLiteException into an accurate diagnosis.
            if (!hasSqliteHeader(file)) {
                val msg = "not a SQLite database: bad file header"
                Log.w(TAG, msg)
                return ReadOutcome.Error(DatabaseSyncResult.Failure(SyncFailureReason.INVALID_FILE, msg))
            }

            db = SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)

            val columnNames = mutableSetOf<String>()
            db.rawQuery("PRAGMA table_info(restaurants)", null).use { cursor ->
                val nameIndex = cursor.getColumnIndex("name")
                while (cursor.moveToNext()) {
                    columnNames.add(cursor.getString(nameIndex))
                }
            }
            if (!columnNames.containsAll(REQUIRED_COLUMNS)) {
                val missing = REQUIRED_COLUMNS - columnNames
                val msg = "missing columns: $missing"
                Log.w(TAG, msg)
                return ReadOutcome.Error(DatabaseSyncResult.Failure(SyncFailureReason.INVALID_FILE, msg))
            }

            // Every name in the projection is one of our own literals; only which
            // of them to include depends on the file. No part of the SQL is built
            // out of the file's own content.
            val projection = REQUIRED_COLUMN_ORDER + OPTIONAL_COLUMNS.filter { it in columnNames }

            val restaurants = mutableListOf<Restaurant>()
            db.rawQuery(
                "SELECT ${projection.joinToString()} FROM restaurants",
                null
            ).use { cursor ->
                // Resolved once rather than per row; -1 when the column is absent.
                val websiteIndex = cursor.getColumnIndex("website")
                val instagramIndex = cursor.getColumnIndex("instagram")
                while (cursor.moveToNext()) {
                    // getString returns null for a NULL column, and these two feed
                    // non-null fields. Coalescing first means the blank check below
                    // reports a real INVALID_FILE instead of throwing an NPE that the
                    // caller can only report as a generic failure.
                    val name = cursor.getString(1) ?: ""
                    val cuisineType = cursor.getString(2) ?: ""
                    val rating = cursor.getInt(4)
                    val priceRange = cursor.getInt(5)

                    if (name.isBlank() || cuisineType.isBlank()) {
                        val msg = "row ${cursor.getLong(0)}: name and cuisineType cannot be empty"
                        Log.w(TAG, msg)
                        return ReadOutcome.Error(
                            DatabaseSyncResult.Failure(SyncFailureReason.INVALID_FILE, msg)
                        )
                    }
                    if (rating !in 0..5 || priceRange !in 0..4) {
                        val msg = "row ${cursor.getLong(0)}: rating must be 0-5, priceRange must be 0-4 (got rating=$rating, priceRange=$priceRange)"
                        Log.w(TAG, msg)
                        return ReadOutcome.Error(
                            DatabaseSyncResult.Failure(SyncFailureReason.INVALID_FILE, msg)
                        )
                    }

                    // An unusable link degrades to null rather than failing the
                    // whole file, the same way an unrecognised cuisine key does:
                    // one bad cell shouldn't cost the user every restaurant.
                    val rawWebsite = cursor.stringAt(websiteIndex)
                    val website = normalizeWebsite(rawWebsite)
                    if (website == null && rawWebsite != null) {
                        Log.w(TAG, "row ${cursor.getLong(0)}: ignoring unusable website")
                    }
                    val rawInstagram = cursor.stringAt(instagramIndex)
                    val instagram = normalizeInstagramHandle(rawInstagram)
                    if (instagram == null && rawInstagram != null) {
                        Log.w(TAG, "row ${cursor.getLong(0)}: ignoring unusable instagram handle")
                    }

                    restaurants.add(
                        Restaurant(
                            id = cursor.getLong(0),
                            name = name,
                            cuisineType = cuisineType,
                            address = if (cursor.isNull(3)) null else cursor.getString(3),
                            rating = rating,
                            priceRange = priceRange,
                            website = website,
                            instagram = instagram
                        )
                    )
                }
            }

            // An empty table is a valid state, not a malformed file: it is the only
            // way to sync your way back to zero restaurants. Files that are genuinely
            // broken are already caught by the header and column checks above.
            Log.d(TAG, "Loaded ${restaurants.size} restaurants")
            ReadOutcome.Rows(restaurants)
        } catch (e: SQLiteException) {
            Log.w(TAG, "SQLite error: ${e.message}", e)
            ReadOutcome.Error(DatabaseSyncResult.Failure(SyncFailureReason.INVALID_FILE, e.message))
        } catch (e: IOException) {
            Log.w(TAG, "IO error reading database: ${e.message}", e)
            ReadOutcome.Error(DatabaseSyncResult.Failure(SyncFailureReason.IO_ERROR, e.message))
        } finally {
            db?.close()
        }
    }

    /**
     * Value of an optional column, or null when the file doesn't have it
     * (`index == -1`) or the cell is NULL.
     */
    private fun Cursor.stringAt(index: Int): String? =
        if (index < 0 || isNull(index)) null else getString(index)

    private fun hasSqliteHeader(file: File): Boolean {
        val header = ByteArray(SQLITE_HEADER.size)
        file.inputStream().use { input ->
            var offset = 0
            while (offset < header.size) {
                val count = input.read(header, offset, header.size - offset)
                if (count == -1) return false
                offset += count
            }
        }
        return header.contentEquals(SQLITE_HEADER)
    }
}
