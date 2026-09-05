package com.saatxi.eatapp.data.photo

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import androidx.test.core.app.ApplicationProvider
import java.io.File
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

/**
 * [AndroidRestaurantPhotoStorage] and the two file-cleanup functions in this
 * file, exercised against real files under Robolectric's `filesDir` — the
 * same approach [com.saatxi.eatapp.data.local.RestaurantDaoTest] already
 * uses for the photo files a restaurant row references.
 *
 * [GraphicsMode.Mode.NATIVE] is required, not the default legacy shadow:
 * legacy `BitmapFactory` fakes a decode for any byte stream regardless of
 * content, which would make both the invalid-image rejection and the actual
 * downsampling/orientation math this class does untestable.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class RestaurantPhotoStorageTest {

    private lateinit var context: Context
    private lateinit var storage: RestaurantPhotoStorage
    private lateinit var sourceDir: File

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        storage = AndroidRestaurantPhotoStorage(context)
        sourceDir = File(context.cacheDir, "test-sources").apply { mkdirs() }
    }

    @After
    fun tearDown() {
        sourceDir.deleteRecursively()
        File(context.filesDir, "photos").deleteRecursively()
    }

    /** A real, decodable JPEG on disk, exposed through a `file://` Uri the same way a picked photo's content Uri resolves. */
    private fun writeSourceImage(name: String, width: Int = 20, height: Int = 10): Uri {
        val file = File(sourceDir, name)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        file.outputStream().use { out -> bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out) }
        return Uri.fromFile(file)
    }

    private fun writeUnreadableFile(name: String): Uri {
        val file = File(sourceDir, name).apply { writeText("not an image") }
        return Uri.fromFile(file)
    }

    @Test
    fun `copies a real picked photo into the app's own storage`() = runTest {
        val source = writeSourceImage("original.jpg")

        val copiedPath = storage.copy(source)

        assertNotNull(copiedPath)
        val copied = File(copiedPath!!)
        assertTrue(copied.exists())
        // Stored under filesDir/photos, never cacheDir — see the class's own kdoc on why.
        assertEquals(File(context.filesDir, "photos"), copied.parentFile)
        assertNotEquals(File(source.path!!).absolutePath, copied.absolutePath)
    }

    @Test
    fun `returns null for a file that is not a decodable image`() = runTest {
        val source = writeUnreadableFile("not-a-photo.txt")

        assertNull(storage.copy(source))
    }

    @Test
    fun `returns null for a uri nothing can be read from`() = runTest {
        val missing = Uri.fromFile(File(sourceDir, "does-not-exist.jpg"))

        assertNull(storage.copy(missing))
    }

    @Test
    fun `each copy gets its own file, even from the same source`() = runTest {
        val source = writeSourceImage("original.jpg")

        val first = storage.copy(source)
        val second = storage.copy(source)

        assertNotNull(first)
        assertNotNull(second)
        assertNotEquals(first, second)
        assertTrue(File(first!!).exists())
        assertTrue(File(second!!).exists())
    }

    @Test
    fun `downsamples a photo larger than the maximum stored dimension`() = runTest {
        // MAX_DIMENSION_PX is 1600; comfortably over it on both sides. The
        // sampling is power-of-two only (see calculateInSampleSize), so the
        // result isn't guaranteed to land at or under 1600 exactly — only
        // smaller than the original, at the same aspect ratio.
        val source = writeSourceImage("huge.jpg", width = 4000, height = 3000)

        val copiedPath = storage.copy(source)

        assertNotNull(copiedPath)
        val decoded = android.graphics.BitmapFactory.decodeFile(copiedPath)
        assertTrue(decoded.width < 4000)
        assertTrue(decoded.height < 3000)
        assertEquals(4000.0 / 3000.0, decoded.width.toDouble() / decoded.height, 0.01)
    }

    @Test
    fun `deleteRestaurantPhotoFile removes the file at the given path`() {
        val file = File(context.filesDir, "photos/to-delete.jpg").apply {
            parentFile?.mkdirs()
            writeText("fake image bytes")
        }

        deleteRestaurantPhotoFile(file.absolutePath)

        assertFalse(file.exists())
    }

    @Test
    fun `deleteRestaurantPhotoFile does not throw for a path that does not exist`() {
        deleteRestaurantPhotoFile(File(context.filesDir, "photos/never-existed.jpg").absolutePath)
    }

    @Test
    fun `deleteAllRestaurantPhotoFiles wipes the whole photos directory`() {
        val photosDir = File(context.filesDir, "photos").apply { mkdirs() }
        File(photosDir, "one.jpg").writeText("a")
        File(photosDir, "two.jpg").writeText("b")

        deleteAllRestaurantPhotoFiles(context)

        assertFalse(photosDir.exists())
    }

    @Test
    fun `a rotated source photo still decodes to a valid file after orientation is applied`() = runTest {
        val file = File(sourceDir, "rotated.jpg")
        val bitmap = Bitmap.createBitmap(30, 20, Bitmap.Config.ARGB_8888)
        file.outputStream().use { out -> bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out) }
        ExifInterface(file.absolutePath).apply {
            setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_ROTATE_90.toString())
            saveAttributes()
        }

        val copiedPath = storage.copy(Uri.fromFile(file))

        assertNotNull(copiedPath)
        val decoded = android.graphics.BitmapFactory.decodeFile(copiedPath)
        // A 90-degree rotation swaps width and height.
        assertEquals(20, decoded.width)
        assertEquals(30, decoded.height)
    }
}
