package com.saatxi.eatapp.data.share

import android.content.Context
import android.net.Uri
import java.io.ByteArrayOutputStream
import java.io.IOException

private const val COPY_BUFFER_SIZE = 8 * 1024

sealed interface ContentReadResult {
    data class Success(val text: String) : ContentReadResult
    data object TooLarge : ContentReadResult
    data object IoError : ContentReadResult
}

/**
 * Reads [uri] fully into memory as UTF-8 text, capped at [maxBytes] — the
 * same defensive limit the old `.db` download used, for the same reason:
 * [uri] can point at anything another app chooses to hand this one.
 */
fun readContentUriCapped(context: Context, uri: Uri, maxBytes: Long = MAX_IMPORT_BYTES): ContentReadResult {
    return try {
        val input = context.contentResolver.openInputStream(uri) ?: return ContentReadResult.IoError
        input.use { stream ->
            val buffer = ByteArray(COPY_BUFFER_SIZE)
            val output = ByteArrayOutputStream()
            while (true) {
                val read = stream.read(buffer)
                if (read == -1) break
                output.write(buffer, 0, read)
                if (output.size() > maxBytes) return ContentReadResult.TooLarge
            }
            ContentReadResult.Success(output.toString(Charsets.UTF_8.name()))
        }
    } catch (e: IOException) {
        ContentReadResult.IoError
    } catch (e: SecurityException) {
        ContentReadResult.IoError
    }
}
