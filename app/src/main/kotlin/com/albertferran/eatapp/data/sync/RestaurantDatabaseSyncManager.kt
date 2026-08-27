package com.albertferran.eatapp.data.sync

import android.content.Context
import android.util.Log
import com.albertferran.eatapp.data.repository.RestaurantRepository
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

private const val CONNECT_TIMEOUT_MS = 15_000
private const val READ_TIMEOUT_MS = 15_000
private const val TAG = "EatApp.Sync"

// A fixed name, so a process death mid-sync leaves behind one file that the next
// download truncates, instead of one more file per attempt forever.
private const val TEMP_FILE_NAME = "sync.db"

// Earlier versions named the temp file sync_<millis>.db, which is exactly how an
// unbounded pile of them could accumulate in cacheDir. Sweep those on the way past.
private const val LEGACY_TEMP_FILE_PREFIX = "sync_"

class RestaurantDatabaseSyncManager(
    private val appContext: Context,
    private val repository: RestaurantRepository
) {
    private val mutex = Mutex()

    suspend fun sync(): DatabaseSyncResult = mutex.withLock {
        withContext(Dispatchers.IO) {
            val tempFile = File(appContext.cacheDir, TEMP_FILE_NAME)
            try {
                deleteLegacyTempFiles()

                val downloadResult = download(tempFile)
                if (downloadResult != null) return@withContext downloadResult

                val readResult = RestaurantDatabaseReader.read(tempFile)
                val restaurants = when (readResult) {
                    is ReadOutcome.Rows -> readResult.restaurants
                    is ReadOutcome.Error -> return@withContext readResult.failure
                }

                repository.replaceAll(restaurants)
                recordSyncTimestamp()
                DatabaseSyncResult.Success(restaurants.size)
            } catch (e: Exception) {
                Log.e(TAG, "Sync failed with unexpected error: ${e.message}", e)
                DatabaseSyncResult.Failure(SyncFailureReason.UNKNOWN, e.message)
            } finally {
                tempFile.delete()
            }
        }
    }

    private fun deleteLegacyTempFiles() {
        val leftovers = appContext.cacheDir
            .listFiles { file -> file.name.startsWith(LEGACY_TEMP_FILE_PREFIX) && file.name.endsWith(".db") }
            ?.takeIf { it.isNotEmpty() }
            ?: return
        Log.d(TAG, "Deleting ${leftovers.size} leftover temp file(s)")
        leftovers.forEach { it.delete() }
    }

    private fun recordSyncTimestamp() {
        val prefs = appContext.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        prefs.edit().putLong(PREF_LAST_SYNC_TIME, System.currentTimeMillis()).apply()
        Log.d(TAG, "Sync completed successfully")
    }

    companion object {
        private const val PREFS_NAME = "com.albertferran.eatapp.sync"
        private const val PREF_LAST_SYNC_TIME = "lastSyncTime"

        fun getLastSyncTime(context: android.content.Context): Long {
            val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
            return prefs.getLong(PREF_LAST_SYNC_TIME, 0L)
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
}
