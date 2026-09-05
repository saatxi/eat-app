package com.saatxi.eatapp.data.local

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * `normalizeTagName` gates both the edit form's chip entry and import
 * validation, so the rejection cases matter as much as the happy path — a
 * tag that slipped through with a comma in it would make
 * `RestaurantUiModel.tagsLabel`'s comma-joined encoding ambiguous to split
 * back apart.
 *
 * Plain Kotlin, no Robolectric — the rule touches nothing Android.
 */
class TagValidationTest {

    @Test
    fun `keeps a normal tag name as written`() {
        assertEquals("Terraza", normalizeTagName("Terraza"))
        assertEquals("para grupos", normalizeTagName("para grupos"))
    }

    @Test
    fun `trims surrounding whitespace`() {
        assertEquals("Terraza", normalizeTagName("  Terraza  "))
    }

    @Test
    fun `treats an empty or blank value as no tag`() {
        assertNull(normalizeTagName(""))
        assertNull(normalizeTagName("   "))
    }

    /** The comma ban is what keeps `tagsLabel`'s encoding unambiguous — see the class doc. */
    @Test
    fun `rejects a name containing a comma`() {
        assertNull(normalizeTagName("terraza, con niños"))
        assertNull(normalizeTagName(","))
    }

    @Test
    fun `accepts a name right at the length limit and rejects one over it`() {
        assertEquals("a".repeat(40), normalizeTagName("a".repeat(40)))
        assertNull(normalizeTagName("a".repeat(41)))
    }

    @Test
    fun `trims before checking the length limit`() {
        // 40 real characters plus padding whitespace should still pass.
        assertEquals("a".repeat(40), normalizeTagName("  " + "a".repeat(40) + "  "))
    }
}
