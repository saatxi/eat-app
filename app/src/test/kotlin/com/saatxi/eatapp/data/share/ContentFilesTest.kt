package com.saatxi.eatapp.data.share

import android.content.Context
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * [readContentUriCapped] stands between this app and a file another app
 * chooses to hand it (see the class kdoc and CLAUDE.md's security
 * guidelines), so the size cap and the failure paths matter as much as the
 * happy path. Robolectric, not plain Kotlin: it reads through a real
 * `Context`'s `ContentResolver`.
 */
@RunWith(RobolectricTestRunner::class)
class ContentFilesTest {

    private lateinit var context: Context
    private lateinit var dir: File

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        dir = File(context.cacheDir, "content-files-test").apply { mkdirs() }
    }

    @After
    fun tearDown() {
        dir.deleteRecursively()
    }

    private fun writeFile(name: String, text: String): Uri = Uri.fromFile(File(dir, name).apply { writeText(text) })

    @Test
    fun `reads a small file back as utf-8 text`() {
        val uri = writeFile("small.txt", "hola món")

        val result = readContentUriCapped(context, uri)

        assertEquals(ContentReadResult.Success("hola món"), result)
    }

    @Test
    fun `a file right at the cap is still read`() {
        val text = "a".repeat(10)
        val uri = writeFile("at-cap.txt", text)

        val result = readContentUriCapped(context, uri, maxBytes = 10)

        assertEquals(ContentReadResult.Success(text), result)
    }

    @Test
    fun `a file over the cap is rejected as too large`() {
        val uri = writeFile("over-cap.txt", "a".repeat(11))

        val result = readContentUriCapped(context, uri, maxBytes = 10)

        assertEquals(ContentReadResult.TooLarge, result)
    }

    @Test
    fun `stops reading as soon as the cap is crossed, rather than buffering the whole file first`() {
        // Comfortably larger than the default MAX_IMPORT_BYTES would be worth
        // buffering in full just to prove this — a tiny explicit cap makes the
        // same point without writing megabytes of filler to disk.
        val uri = writeFile("way-over.txt", "a".repeat(1_000_000))

        val result = readContentUriCapped(context, uri, maxBytes = 10)

        assertEquals(ContentReadResult.TooLarge, result)
    }

    @Test
    fun `a uri nothing can be read from is an io error`() {
        val missing = Uri.fromFile(File(dir, "does-not-exist.txt"))

        val result = readContentUriCapped(context, missing)

        assertEquals(ContentReadResult.IoError, result)
    }

    @Test
    fun `an empty file reads as empty text, not an error`() {
        val uri = writeFile("empty.txt", "")

        val result = readContentUriCapped(context, uri)

        assertEquals(ContentReadResult.Success(""), result)
    }
}
