package com.saatxi.eatapp.data.local

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * These two functions stand between a user-entered value and an
 * `Intent.ACTION_VIEW`, so the rejection cases matter more than the happy
 * path: a scheme that slipped through here would let a restaurant's own data
 * choose what the app launches.
 *
 * Plain Kotlin, no Robolectric — the rules deliberately don't touch `Uri`.
 */
class LinkValidationTest {

    @Test
    fun `keeps an http or https url as written`() {
        assertEquals("https://example.com", normalizeWebsite("https://example.com"))
        assertEquals("http://example.com/menu", normalizeWebsite("http://example.com/menu"))
    }

    @Test
    fun `assumes https for a bare host, which is how people tend to type it`() {
        assertEquals("https://example.com", normalizeWebsite("example.com"))
        assertEquals("https://example.com/menu", normalizeWebsite("example.com/menu"))
    }

    @Test
    fun `matches the scheme case-insensitively`() {
        assertEquals("HTTPS://example.com", normalizeWebsite("HTTPS://example.com"))
    }

    @Test
    fun `trims surrounding whitespace`() {
        assertEquals("https://example.com", normalizeWebsite("  https://example.com  "))
    }

    @Test
    fun `treats a missing, empty or blank value as no website`() {
        assertNull(normalizeWebsite(null))
        assertNull(normalizeWebsite(""))
        assertNull(normalizeWebsite("   "))
    }

    /** The reason this file exists. */
    @Test
    fun `rejects every scheme that is not http or https`() {
        assertNull(normalizeWebsite("javascript:alert(1)"))
        assertNull(normalizeWebsite("intent://scan/#Intent;scheme=zxing;end"))
        assertNull(normalizeWebsite("file:///data/data/com.saatxi.eatapp/databases/eatapp.db"))
        assertNull(normalizeWebsite("content://com.android.contacts/contacts"))
        assertNull(normalizeWebsite("data:text/html,<script>alert(1)</script>"))
        assertNull(normalizeWebsite("eatapp://whatever"))
    }

    @Test
    fun `accepts an instagram handle with or without the at sign`() {
        assertEquals("cal_ferran", normalizeInstagramHandle("cal_ferran"))
        assertEquals("cal_ferran", normalizeInstagramHandle("@cal_ferran"))
        assertEquals("cal.ferran99", normalizeInstagramHandle("  @cal.ferran99  "))
    }

    @Test
    fun `rejects a handle with characters instagram does not allow`() {
        assertNull(normalizeInstagramHandle("cal ferran"))
        assertNull(normalizeInstagramHandle("cal/ferran"))
        assertNull(normalizeInstagramHandle("cal-ferran"))
        // A full URL is not a handle: storing one would hand user input control
        // over the scheme, which is exactly what this design avoids.
        assertNull(normalizeInstagramHandle("https://instagram.com/cal_ferran"))
    }

    @Test
    fun `rejects an empty handle or one longer than instagram allows`() {
        assertNull(normalizeInstagramHandle(null))
        assertNull(normalizeInstagramHandle(""))
        assertNull(normalizeInstagramHandle("@"))
        assertEquals("a".repeat(30), normalizeInstagramHandle("a".repeat(30)))
        assertNull(normalizeInstagramHandle("a".repeat(31)))
    }

    @Test
    fun `builds the profile url from the handle rather than parsing one`() {
        assertEquals("https://instagram.com/cal_ferran", instagramUrl("cal_ferran"))
    }
}
