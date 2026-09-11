package com.saatxi.eatapp.data.share

import android.content.Context
import androidx.core.content.FileProvider
import androidx.test.core.app.ApplicationProvider
import java.io.File
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * [writeRestaurantShareFile] writes under `cacheDir/shared/` — the one
 * subdirectory `res/xml/file_paths.xml` exposes through the `FileProvider` —
 * and hands back a `content://` Uri another app can be granted read access
 * to. Robolectric: needs the real `FileProvider` declared in the manifest,
 * and a real `cacheDir`.
 *
 * Two Robolectric/host quirks around `FileProvider`, neither a bug in this
 * app, need working around here:
 *
 * - `FileProvider` caches the parsed `PathStrategy` per authority in a
 *   private static `sCache` map for the classloader's lifetime — fine on a
 *   real device, where `cacheDir` never moves, but Robolectric hands out a
 *   fresh `cacheDir` under a new temp directory for every test method while
 *   reusing the same classloader (and so the same `sCache`) across the whole
 *   class. Left alone, only the first test method to call
 *   [writeRestaurantShareFile] resolves the root correctly; every later one
 *   fails with `IllegalArgumentException: Failed to find configured root`
 *   because it's matched against a previous test's now-gone temp dir.
 *   [resetFileProviderPathStrategyCache] clears that static map before each
 *   test so `FileProvider` re-resolves it against the *current* test's
 *   `context`.
 * - Skipped on Windows (see [setUp]): even with a freshly-resolved root,
 *   `SimplePathStrategy.belongsToRoot` hardcodes a `/` separator when
 *   checking whether a file's canonical path sits under it — correct on a
 *   real device, where the filesystem is always `/`-separated, but
 *   Robolectric runs this as plain JVM code against the *host* filesystem,
 *   and `File.getCanonicalPath()` on Windows returns `\`-separated paths.
 *   The root and the file both resolve correctly (verified directly: both
 *   canonicalize to the same `cacheDir\shared` prefix), but the hardcoded
 *   `rootPath + '/'` check can never match a `\`-joined path, so every call
 *   to `FileProvider.getUriForFile` throws here regardless of the cache fix
 *   above — a genuine host-OS limitation of the library under test. The CI
 *   workflow (`ci.yml`) runs on `ubuntu-latest`, where this isn't an issue,
 *   so this file still gets exercised there even though it skips here.
 */
@RunWith(RobolectricTestRunner::class)
class RestaurantShareWriterTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        assumeTrue("FileProvider path-matching is / -only; skipped on Windows, see class kdoc", File.separatorChar == '/')
        resetFileProviderPathStrategyCache()
        context = ApplicationProvider.getApplicationContext()
    }

    private fun resetFileProviderPathStrategyCache() {
        val cacheField = FileProvider::class.java.getDeclaredField("sCache")
        cacheField.isAccessible = true
        (cacheField.get(null) as MutableMap<*, *>).clear()
    }

    @After
    fun tearDown() {
        if (File.separatorChar == '/') {
            File(context.cacheDir, "shared").deleteRecursively()
        }
    }

    private fun export(name: String) = RestaurantExport(
        name = name,
        cuisineType = "mediterranean",
        streetAddress = null,
        rating = 3,
        priceRange = 2
    )

    @Test
    fun `writes the file under cacheDir shared`() {
        writeRestaurantShareFile(context, listOf(export("Cal Ferran")))

        val file = File(context.cacheDir, "shared/restaurants.eatapp")
        assertTrue(file.exists())
    }

    @Test
    fun `returns a content uri through the app's own fileprovider authority`() {
        val uri = writeRestaurantShareFile(context, listOf(export("Cal Ferran")))

        assertEquals("content", uri.scheme)
        assertEquals("${context.packageName}.fileprovider", uri.authority)
    }

    @Test
    fun `writes every restaurant passed in`() {
        writeRestaurantShareFile(context, listOf(export("Cal Ferran"), export("Bar Nil")))

        val shareFile = Json.decodeFromString(
            RestaurantShareFile.serializer(),
            File(context.cacheDir, "shared/restaurants.eatapp").readText()
        )
        assertEquals(listOf("Cal Ferran", "Bar Nil"), shareFile.restaurants.map { it.name })
    }

    @Test
    fun `each write fully replaces the previous content rather than appending`() {
        writeRestaurantShareFile(context, listOf(export("Old One")))

        writeRestaurantShareFile(context, listOf(export("New One")))

        val shareFile = Json.decodeFromString(
            RestaurantShareFile.serializer(),
            File(context.cacheDir, "shared/restaurants.eatapp").readText()
        )
        assertEquals(listOf("New One"), shareFile.restaurants.map { it.name })
    }

    @Test
    fun `an empty list still produces a valid, readable file`() {
        val uri = writeRestaurantShareFile(context, emptyList())

        assertNotEquals(null, uri)
        val shareFile = Json.decodeFromString(
            RestaurantShareFile.serializer(),
            File(context.cacheDir, "shared/restaurants.eatapp").readText()
        )
        assertTrue(shareFile.restaurants.isEmpty())
    }
}
