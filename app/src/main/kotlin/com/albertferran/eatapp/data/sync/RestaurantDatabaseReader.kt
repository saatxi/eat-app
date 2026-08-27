package com.albertferran.eatapp.data.sync

import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import android.util.Log
import com.albertferran.eatapp.data.local.Restaurant
import java.io.File
import java.io.IOException
import java.time.LocalDate

internal val REQUIRED_COLUMNS = setOf(
    "id", "name", "cuisineType", "address", "rating", "priceRange",
    "notes", "visitDate", "photoUri", "createdAt"
)

private const val TAG = "EatApp.Sync"

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

            val restaurants = mutableListOf<Restaurant>()
            db.rawQuery(
                """
                SELECT id, name, cuisineType, address, rating, priceRange, notes, visitDate, photoUri, createdAt
                FROM restaurants
                """.trimIndent(),
                null
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    // getString returns null for a NULL column, and these three feed
                    // non-null fields. Coalescing first means the blank check below
                    // reports a real INVALID_FILE instead of throwing an NPE that the
                    // caller can only report as a generic failure.
                    val name = cursor.getString(1) ?: ""
                    val cuisineType = cursor.getString(2) ?: ""
                    val notes = cursor.getString(6) ?: ""
                    val rating = cursor.getInt(4)
                    val priceRange = cursor.getInt(5)

                    if (name.isBlank() || cuisineType.isBlank() || notes.isBlank()) {
                        val msg = "row ${cursor.getLong(0)}: name, cuisineType and notes cannot be empty"
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

                    restaurants.add(
                        Restaurant(
                            id = cursor.getLong(0),
                            name = name,
                            cuisineType = cuisineType,
                            address = if (cursor.isNull(3)) null else cursor.getString(3),
                            rating = rating,
                            priceRange = priceRange,
                            notes = notes,
                            visitDate = LocalDate.ofEpochDay(cursor.getLong(7)),
                            photoUri = if (cursor.isNull(8)) null else cursor.getString(8),
                            createdAt = cursor.getLong(9)
                        )
                    )
                }
            }

            if (restaurants.isEmpty()) {
                Log.w(TAG, "No rows found in restaurants table")
                ReadOutcome.Error(DatabaseSyncResult.Failure(SyncFailureReason.INVALID_FILE, "no rows in restaurants table"))
            } else {
                Log.d(TAG, "Loaded ${restaurants.size} restaurants")
                ReadOutcome.Rows(restaurants)
            }
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
}
