package com.saatxi.eatapp.data.sync

sealed interface DatabaseSyncResult {
    data class Success(val importedCount: Int) : DatabaseSyncResult

    /** The server confirmed (via a 304) that the local data already matches the remote file. */
    data object UpToDate : DatabaseSyncResult
    data class Failure(val reason: SyncFailureReason, val detail: String? = null) : DatabaseSyncResult
}

enum class SyncFailureReason { NETWORK, INVALID_FILE, IO_ERROR, UNKNOWN }
