package com.albertferran.eatapp.data.local

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CuisineTest {

    @Test
    fun `resolves an exact key`() {
        assertEquals(Cuisine.JAPANESE, Cuisine.fromKey("japanese"))
        assertEquals(Cuisine.FAST_FOOD, Cuisine.fromKey("fast_food"))
    }

    @Test
    fun `is forgiving about case and surrounding whitespace`() {
        assertEquals(Cuisine.ITALIAN, Cuisine.fromKey("  Italian "))
        assertEquals(Cuisine.WINE_BAR, Cuisine.fromKey("WINE_BAR"))
    }

    @Test
    fun `degrades gracefully on an unknown key rather than throwing`() {
        // A newer data file must never break an older build; the UI falls back
        // to the raw string and a generic icon.
        assertNull(Cuisine.fromKey("sushi"))
        assertNull(Cuisine.fromKey("Japonesa"))
        assertNull(Cuisine.fromKey(""))
    }

    @Test
    fun `handles a null key`() {
        assertNull(Cuisine.fromKey(null))
    }

    @Test
    fun `every key is unique`() {
        val keys = Cuisine.entries.map { it.key }
        assertEquals(keys.size, keys.toSet().size)
    }

    @Test
    fun `keys are lowercase, so fromKey can round-trip every entry`() {
        Cuisine.entries.forEach { cuisine ->
            assertEquals(cuisine.key, cuisine.key.lowercase())
            assertEquals(cuisine, Cuisine.fromKey(cuisine.key))
        }
    }

    @Test
    fun `the vocabulary is the documented 22 keys`() {
        // Guards the README and Cuisine.kt against drifting apart silently.
        assertEquals(22, Cuisine.entries.size)
    }
}
