package com.albertferran.eatapp.data.sync

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import android.util.Log
import com.albertferran.eatapp.data.local.Restaurant
import com.albertferran.eatapp.data.repository.RestaurantRepository
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

private val REQUIRED_COLUMNS = setOf(
    "id", "name", "cuisineType", "address", "rating", "priceRange",
    "notes", "visitDate", "photoUri", "createdAt"
)

private const val CONNECT_TIMEOUT_MS = 15_000
private const val READ_TIMEOUT_MS = 15_000
private const val TAG = "EatApp.Sync"

class RestaurantDatabaseSyncManager(
    private val appContext: Context,
    private val repository: RestaurantRepository
) {
    private val mutex = Mutex()

    suspend fun sync(): DatabaseSyncResult = mutex.withLock {
        withContext(Dispatchers.IO) {
            val tempFile = File(appContext.cacheDir, "sync_${System.currentTimeMillis()}.db")
            try {
                val downloadResult = download(tempFile)
                if (downloadResult != null) return@withContext downloadResult

                val readResult = readRestaurants(tempFile)
                val restaurants = when (readResult) {
                    is ReadOutcome.Rows -> readResult.restaurants
                    is ReadOutcome.Error -> return@withContext readResult.failure
                }

                repository.replaceAll(restaurants)
                DatabaseSyncResult.Success(restaurants.size)
            } catch (e: Exception) {
                Log.e(TAG, "Sync failed with unexpected error: ${e.message}", e)
                DatabaseSyncResult.Failure(SyncFailureReason.UNKNOWN, e.message)
            } finally {
                tempFile.delete()
            }
        }
    }

    private fun download(destination: File): DatabaseSyncResult.Failure? {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(RemoteConfig.DATABASE_URL).openConnection() as HttpURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                instanceFollowRedirects = true
                requestMethod = "GET"
            }
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                val msg = "HTTP ${connection.responseCode}"
                Log.w(TAG, "Download failed: $msg")
                return DatabaseSyncResult.Failure(SyncFailureReason.NETWORK, msg)
            }
            connection.inputStream.use { input ->
                destination.outputStream().use { output -> input.copyTo(output) }
            }
            null
        } catch (e: IOException) {
            Log.w(TAG, "Download error: ${e.message}", e)
            DatabaseSyncResult.Failure(SyncFailureReason.NETWORK, e.message)
        } finally {
            connection?.disconnect()
        }
    }

    private sealed interface ReadOutcome {
        data class Rows(val restaurants: List<Restaurant>) : ReadOutcome
        data class Error(val failure: DatabaseSyncResult.Failure) : ReadOutcome
    }

    private fun readRestaurants(file: File): ReadOutcome {
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
                    val name = cursor.getString(1)
                    val cuisineType = cursor.getString(2)
                    val notes = cursor.getString(6)
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
