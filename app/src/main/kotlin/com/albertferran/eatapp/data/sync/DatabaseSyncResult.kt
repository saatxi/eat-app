package com.albertferran.eatapp.data.sync

sealed interface DatabaseSyncResult {
    data class Success(val importedCount: Int) : DatabaseSyncResult
    data class Failure(val reason: SyncFailureReason, val detail: String? = null) : DatabaseSyncResult
}

enum class SyncFailureReason { NETWORK, INVALID_FILE, IO_ERROR, UNKNOWN }
