package com.saatxi.eatapp.data.photo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.IOException
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private const val TAG = "EatApp.Photo"
private const val PHOTO_DIR_NAME = "photos"

/** Longest side a stored photo is allowed to be — see [AndroidRestaurantPhotoStorage.copy]. */
private const val MAX_DIMENSION_PX = 1600
private const val JPEG_QUALITY = 85

/**
 * Turns a picked photo into a durable copy this app owns. Pulled out as an
 * interface — rather than a plain function taking [Context] — purely so
 * `RestaurantEditViewModel` can be unit tested against a fake instead of
 * needing a real `ContentResolver`, the same reasoning that put
 * `DatabaseSyncManager` behind an interface for the old sync feature.
 */
fun interface RestaurantPhotoStorage {
    /**
     * Copies the image [source] points at into this app's private storage and
     * returns the absolute path of the copy, or null if it couldn't be read or
     * decoded — the caller falls back to leaving whatever photo was there
     * before, rather than losing it over one failed pick.
     */
    suspend fun copy(source: Uri): String?
}

/**
 * Reads through [Context.getContentResolver], so [source] only ever needs to
 * be readable for as long as this call takes — unlike the Photo Picker's own
 * `content://` grant, whose lifetime this app doesn't want to depend on, the
 * copy this produces lives under [Context.getFilesDir] for as long as the
 * restaurant that references it does.
 */
class AndroidRestaurantPhotoStorage(private val context: Context) : RestaurantPhotoStorage {

    override suspend fun copy(source: Uri): String? = withContext(Dispatchers.IO) {
        try {
            val boundsStream = context.contentResolver.openInputStream(source) ?: return@withContext null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            boundsStream.use { BitmapFactory.decodeStream(it, null, bounds) }
            // decodeStream always returns null for a bounds-only pass; outWidth/outHeight
            // staying unset (-1) is what actually signals an unreadable or unrecognised image.
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return@withContext null

            val sampleSize = calculateInSampleSize(bounds.outWidth, bounds.outHeight, MAX_DIMENSION_PX)
            val decoded = context.contentResolver.openInputStream(source)?.use { stream ->
                BitmapFactory.decodeStream(stream, null, BitmapFactory.Options().apply { inSampleSize = sampleSize })
            } ?: return@withContext null

            // A fresh stream: the one just consumed by decodeStream is already spent.
            val orientation = context.contentResolver.openInputStream(source)?.use { stream ->
                ExifInterface(stream).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            } ?: ExifInterface.ORIENTATION_NORMAL
            val oriented = applyExifOrientation(decoded, orientation)

            val photosDir = File(context.filesDir, PHOTO_DIR_NAME).apply { mkdirs() }
            val destination = File(photosDir, "${UUID.randomUUID()}.jpg")
            destination.outputStream().use { out ->
                oriented.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
            }
            if (oriented !== decoded) decoded.recycle()
            oriented.recycle()

            destination.absolutePath
        } catch (e: IOException) {
            Log.w(TAG, "Failed to copy picked photo", e)
            null
        } catch (e: SecurityException) {
            Log.w(TAG, "No permission to read the picked photo", e)
            null
        } catch (e: OutOfMemoryError) {
            Log.w(TAG, "Picked photo was too large to decode", e)
            null
        }
    }
}

/** Halves the decode target until it's within [maxDimension], the same doubling BitmapFactory expects. */
private fun calculateInSampleSize(width: Int, height: Int, maxDimension: Int): Int {
    var sampleSize = 1
    var longestSide = maxOf(width, height)
    while (longestSide / 2 >= maxDimension) {
        sampleSize *= 2
        longestSide /= 2
    }
    return sampleSize
}

/**
 * Bakes the EXIF orientation into the pixels themselves, so nothing that
 * displays the stored copy later needs to know about EXIF at all. Only the
 * rotate/flip cases an actual camera produces are handled; the two rare
 * transpose/transverse combinations are left unrotated rather than guessed at.
 */
private fun applyExifOrientation(bitmap: Bitmap, orientation: Int): Bitmap {
    val matrix = Matrix()
    when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
        ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
        ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
        ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
        ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
        else -> return bitmap
    }
    return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
}

/**
 * Deletes one stored photo. [path] is already absolute (see
 * [Restaurant.photoPath][com.saatxi.eatapp.data.local.Restaurant]), so this
 * needs no [Context] — called by `RoomRestaurantRepository` once [update] or
 * [delete] has moved a row past this file.
 */
fun deleteRestaurantPhotoFile(path: String) {
    try {
        File(path).delete()
    } catch (e: SecurityException) {
        Log.w(TAG, "Failed to delete photo file", e)
    }
}

/** Wipes every stored photo at once — used by `deleteAll()`, after which nothing references any of them. */
fun deleteAllRestaurantPhotoFiles(context: Context) {
    File(context.filesDir, PHOTO_DIR_NAME).deleteRecursively()
}
