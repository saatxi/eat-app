package com.saatxi.eatapp.data.share

import android.content.Context
import android.net.Uri
import java.io.ByteArrayOutputStream
import java.io.IOException

private const val COPY_BUFFER_SIZE = 8 * 1024

/**
 * A `content://` Uri from an app like Gmail can briefly fail to open right
 * after "Open with" is tapped — the attachment isn't fully cached on-device
 * yet — but succeeds moments later. Retrying the whole open-and-read a few
 * times, with a short pause, absorbs that without the user having to
 * manually download the attachment first and reopen it from a file manager.
 */
private const val MAX_ATTEMPTS = 3
private const val RETRY_DELAY_MILLIS = 300L

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
    repeat(MAX_ATTEMPTS) { attempt ->
        val result = readContentUriOnce(context, uri, maxBytes)
        if (result !is ContentReadResult.IoError || attempt == MAX_ATTEMPTS - 1) return result
        Thread.sleep(RETRY_DELAY_MILLIS)
    }
    error("unreachable — repeat() above always returns on its last iteration")
}

private fun readContentUriOnce(context: Context, uri: Uri, maxBytes: Long): ContentReadResult {
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
