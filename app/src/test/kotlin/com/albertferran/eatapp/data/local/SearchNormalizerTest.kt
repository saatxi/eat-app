package com.albertferran.eatapp.data.local

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The folding behind F-14. SQLite's LIKE folds neither accents nor non-ASCII
 * case, so everything that makes search work lives in these two functions.
 */
class SearchNormalizerTest {

    @Test
    fun `strips accents`() {
        assertEquals("mediterranea", normalizeForSearch("Mediterránea"))
        assertEquals("mataro", normalizeForSearch("Mataró"))
        assertEquals("doner", normalizeForSearch("Döner"))
        assertEquals("cafe", normalizeForSearch("Café"))
    }

    @Test
    fun `strips the cedilla, which decomposes like an accent`() {
        assertEquals("placa", normalizeForSearch("Plaça"))
    }

    @Test
    fun `folds case`() {
        assertEquals("japanese", normalizeForSearch("JAPANESE"))
        assertEquals("fast food", normalizeForSearch("Fast Food"))
    }

    @Test
    fun `is idempotent, so folding an already folded value is safe`() {
        val once = normalizeForSearch("Plaça Santa Anna, Mataró")
        assertEquals(once, normalizeForSearch(once))
    }

    @Test
    fun `leaves unaccented ascii alone`() {
        assertEquals("barcelona", normalizeForSearch("barcelona"))
    }

    @Test
    fun `handles the empty string`() {
        assertEquals("", normalizeForSearch(""))
    }

    @Test
    fun `matching works in both directions, which is the point of F-14`() {
        // Query without accents finds accented data, and the reverse.
        assertTrue(normalizeForSearch("Mediterránea").contains(normalizeForSearch("Mediterranea")))
        assertTrue(normalizeForSearch("Mediterranea").contains(normalizeForSearch("Mediterránea")))
    }

    @Test
    fun `buildSearchText covers every searchable field`() {
        val text = buildSearchText(
            name = "Cal Ferran",
            cuisineType = "mediterranean",
            address = "Plaça Santa Anna, Mataró"
        )
        assertTrue(text.contains("cal ferran"))
        assertTrue(text.contains("mediterranean"))
        assertTrue(text.contains("placa santa anna"))
    }

    @Test
    fun `buildSearchText tolerates a null address`() {
        val text = buildSearchText(
            name = "Nil",
            cuisineType = "cafe",
            address = null
        )
        assertEquals("nil cafe", text)
    }

    @Test
    fun `buildSearchText output is itself normalized`() {
        val text = buildSearchText("Café Niló", "cafe", "Rambla")
        assertEquals(text, normalizeForSearch(text))
    }

    // --- escapeLikeWildcards, which is F-15 ---------------------------------

    @Test
    fun `escapes percent and underscore`() {
        assertEquals("100\\%", escapeLikeWildcards("100%"))
        assertEquals("cal\\_ferran", escapeLikeWildcards("cal_ferran"))
    }

    @Test
    fun `escapes a literal backslash so it does not act as the escape character`() {
        assertEquals("cal\\\\ferran", escapeLikeWildcards("cal\\ferran"))
    }

    @Test
    fun `leaves ordinary text alone`() {
        assertEquals("cal ferran", escapeLikeWildcards("cal ferran"))
    }
}
