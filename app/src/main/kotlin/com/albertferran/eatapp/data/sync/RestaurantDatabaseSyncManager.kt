package com.albertferran.eatapp.data.sync

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
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
                return DatabaseSyncResult.Failure(SyncFailureReason.NETWORK, "HTTP ${connection.responseCode}")
            }
            connection.inputStream.use { input ->
                destination.outputStream().use { output -> input.copyTo(output) }
            }
            null
        } catch (e: IOException) {
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
                return ReadOutcome.Error(DatabaseSyncResult.Failure(SyncFailureReason.INVALID_FILE, "missing columns"))
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
                    restaurants.add(
                        Restaurant(
                            id = cursor.getLong(0),
                            name = cursor.getString(1),
                            cuisineType = cursor.getString(2),
                            address = if (cursor.isNull(3)) null else cursor.getString(3),
                            rating = cursor.getInt(4),
                            priceRange = cursor.getInt(5),
                            notes = cursor.getString(6),
                            visitDate = LocalDate.ofEpochDay(cursor.getLong(7)),
                            photoUri = if (cursor.isNull(8)) null else cursor.getString(8),
                            createdAt = cursor.getLong(9)
                        )
                    )
                }
            }

            if (restaurants.isEmpty()) {
                ReadOutcome.Error(DatabaseSyncResult.Failure(SyncFailureReason.INVALID_FILE, "empty dataset"))
            } else {
                ReadOutcome.Rows(restaurants)
            }
        } catch (e: SQLiteException) {
            ReadOutcome.Error(DatabaseSyncResult.Failure(SyncFailureReason.INVALID_FILE, e.message))
        } catch (e: IOException) {
            ReadOutcome.Error(DatabaseSyncResult.Failure(SyncFailureReason.IO_ERROR, e.message))
        } finally {
            db?.close()
        }
    }
}
