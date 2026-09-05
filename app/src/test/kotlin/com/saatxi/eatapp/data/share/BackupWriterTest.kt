package com.saatxi.eatapp.data.share

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import java.io.File
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * [writeBackupFile] writes under `filesDir`, not `cacheDir` — see its own
 * kdoc for why that distinction matters for Auto Backup — so this checks
 * both the file's location and its content. Robolectric: real `filesDir`.
 */
@RunWith(RobolectricTestRunner::class)
class BackupWriterTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
    }

    @After
    fun tearDown() {
        File(context.filesDir, "backup.json").delete()
    }

    private fun export(name: String) = RestaurantExport(
        name = name,
        cuisineType = "mediterranean",
        address = null,
        rating = 3,
        priceRange = 2
    )

    @Test
    fun `writes the backup file under filesDir, not cacheDir`() {
        writeBackupFile(context, listOf(export("Cal Ferran")))

        assertTrue(File(context.filesDir, "backup.json").exists())
        assertTrue(File(context.cacheDir, "backup.json").exists().not())
    }

    @Test
    fun `writes every restaurant passed in`() {
        writeBackupFile(context, listOf(export("Cal Ferran"), export("Bar Nil")))

        val shareFile = Json.decodeFromString(
            RestaurantShareFile.serializer(),
            File(context.filesDir, "backup.json").readText()
        )
        assertEquals(listOf("Cal Ferran", "Bar Nil"), shareFile.restaurants.map { it.name })
    }

    @Test
    fun `an empty list writes a file with no restaurants, not no file at all`() {
        writeBackupFile(context, emptyList())

        val shareFile = Json.decodeFromString(
            RestaurantShareFile.serializer(),
            File(context.filesDir, "backup.json").readText()
        )
        assertTrue(shareFile.restaurants.isEmpty())
    }

    @Test
    fun `each write fully replaces the previous content rather than appending`() {
        writeBackupFile(context, listOf(export("Old One"), export("Old Two")))

        writeBackupFile(context, listOf(export("New One")))

        val shareFile = Json.decodeFromString(
            RestaurantShareFile.serializer(),
            File(context.filesDir, "backup.json").readText()
        )
        assertEquals(listOf("New One"), shareFile.restaurants.map { it.name })
    }

    @Test
    fun `the written file decodes with the format the reader gates on`() {
        // The `format` field isn't necessarily present in the raw JSON — it has
        // a default and kotlinx.serialization omits fields equal to their
        // default — so this checks the *decoded* value, which is what
        // RestaurantImportReader actually gates on, not the raw text.
        writeBackupFile(context, listOf(export("Cal Ferran")))

        val shareFile = Json.decodeFromString(
            RestaurantShareFile.serializer(),
            File(context.filesDir, "backup.json").readText()
        )
        assertEquals(RestaurantShareFile.FORMAT, shareFile.format)
    }
}
