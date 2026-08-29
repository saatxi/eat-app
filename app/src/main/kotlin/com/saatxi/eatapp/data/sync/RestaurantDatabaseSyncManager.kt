package com.saatxi.eatapp.data.sync

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import com.saatxi.eatapp.data.repository.RestaurantRepository
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
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

// The file is untrusted input landing in cacheDir; this dataset is a handful of KB,
// so 10 MB is generous headroom without leaving the download effectively unbounded.
private const val MAX_DOWNLOAD_BYTES = 10L * 1024 * 1024
private const val COPY_BUFFER_SIZE = 8 * 1024

/**
 * Abstracts the sync operation behind an interface so a ViewModel can be tested against
 * a hand-written fake instead of [RestaurantDatabaseSyncManager]'s real network call.
 */
fun interface DatabaseSyncManager {
    suspend fun sync(): DatabaseSyncResult
}

class RestaurantDatabaseSyncManager(
    private val appContext: Context,
    private val repository: RestaurantRepository
) : DatabaseSyncManager {
    private val mutex = Mutex()

    override suspend fun sync(): DatabaseSyncResult = mutex.withLock {
        withContext(Dispatchers.IO) {
            if (!hasNetworkConnection()) {
                Log.w(TAG, "Sync skipped: no network connection")
                return@withContext DatabaseSyncResult.Failure(SyncFailureReason.NETWORK, "no network connection")
            }

            val tempFile = File(appContext.cacheDir, TEMP_FILE_NAME)
            try {
                deleteLegacyTempFiles()

                // An empty local table must never be short-circuited by a stale ETag: if the
                // database was cleared (a destructive migration, a manual reset during
                // development) while the ETag pref survived, honoring it would make a 304
                // permanently skip repopulating the data with no way to recover but a
                // reinstall. Only rely on the cached ETag when there is data it can match.
                val previousETag = if (repository.count() > 0) getStoredETag() else null

                when (val outcome = download(tempFile, previousETag)) {
                    is DownloadOutcome.Failed -> return@withContext outcome.failure

                    DownloadOutcome.NotModified -> {
                        recordSyncTimestamp()
                        return@withContext DatabaseSyncResult.UpToDate
                    }

                    is DownloadOutcome.Downloaded -> {
                        val readResult = RestaurantDatabaseReader.read(tempFile)
                        val restaurants = when (readResult) {
                            is ReadOutcome.Rows -> readResult.restaurants
                            is ReadOutcome.Error -> return@withContext readResult.failure
                        }

                        repository.replaceAll(restaurants)
                        recordSyncTimestamp()
                        saveETag(outcome.etag)
                        DatabaseSyncResult.Success(restaurants.size)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Sync failed with unexpected error: ${e.message}", e)
                DatabaseSyncResult.Failure(SyncFailureReason.UNKNOWN, e.message)
            } finally {
                tempFile.delete()
            }
        }
    }

    private fun hasNetworkConnection(): Boolean {
        val connectivityManager =
            appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return true // Fail open: let the request itself be the source of truth.
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
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
        val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putLong(PREF_LAST_SYNC_TIME, System.currentTimeMillis()).apply()
        Log.d(TAG, "Sync completed successfully")
    }

    private fun getStoredETag(): String? =
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).getString(PREF_ETAG, null)

    private fun saveETag(etag: String?) {
        val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (etag != null) prefs.edit().putString(PREF_ETAG, etag).apply() else prefs.edit().remove(PREF_ETAG).apply()
    }

    companion object {
        private const val PREFS_NAME = "com.saatxi.eatapp.sync"
        private const val PREF_LAST_SYNC_TIME = "lastSyncTime"
        private const val PREF_ETAG = "etag"

        fun getLastSyncTime(context: Context): Long {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getLong(PREF_LAST_SYNC_TIME, 0L)
        }
    }

    private fun download(destination: File, previousETag: String?): DownloadOutcome {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(RemoteConfig.DATABASE_URL).openConnection() as HttpURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                instanceFollowRedirects = true
                requestMethod = "GET"
                if (previousETag != null) {
                    setRequestProperty("If-None-Match", previousETag)
                }
            }
            when (connection.responseCode) {
                HttpURLConnection.HTTP_NOT_MODIFIED -> DownloadOutcome.NotModified

                HttpURLConnection.HTTP_OK -> {
                    val fitsWithinLimit = connection.inputStream.use { input ->
                        destination.outputStream().use { output ->
                            copyUpToLimit(input, output, MAX_DOWNLOAD_BYTES)
                        }
                    }
                    if (fitsWithinLimit) {
                        DownloadOutcome.Downloaded(connection.getHeaderField("ETag"))
                    } else {
                        val msg = "download exceeded the ${MAX_DOWNLOAD_BYTES / (1024 * 1024)} MB limit"
                        Log.w(TAG, msg)
                        DownloadOutcome.Failed(DatabaseSyncResult.Failure(SyncFailureReason.INVALID_FILE, msg))
                    }
                }

                else -> {
                    val msg = "HTTP ${connection.responseCode}"
                    Log.w(TAG, "Download failed: $msg")
                    DownloadOutcome.Failed(DatabaseSyncResult.Failure(SyncFailureReason.NETWORK, msg))
                }
            }
        } catch (e: IOException) {
            Log.w(TAG, "Download error: ${e.message}", e)
            DownloadOutcome.Failed(DatabaseSyncResult.Failure(SyncFailureReason.NETWORK, e.message))
        } finally {
            connection?.disconnect()
        }
    }
}

private sealed interface DownloadOutcome {
    data class Downloaded(val etag: String?) : DownloadOutcome
    data object NotModified : DownloadOutcome
    data class Failed(val failure: DatabaseSyncResult.Failure) : DownloadOutcome
}

/**
 * Copies [input] into [output], stopping the moment more than [limit] bytes have been
 * read. Returns true if the whole stream fit within the limit, false if it was cut off —
 * the caller is expected to discard [output] in that case rather than treat it as complete.
 */
internal fun copyUpToLimit(input: InputStream, output: OutputStream, limit: Long): Boolean {
    val buffer = ByteArray(COPY_BUFFER_SIZE)
    var total = 0L
    while (true) {
        val read = input.read(buffer)
        if (read == -1) return true
        total += read
        if (total > limit) return false
        output.write(buffer, 0, read)
    }
}
