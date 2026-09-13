package com.saatxi.eatapp.data.mapslink

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * [resolveMapsLink] is the one place this app makes a network call (see
 * CLAUDE.md's "Networking" section), so the rejection cases matter as much
 * as the happy path: a host outside the allowlist must never reach
 * [UrlRedirectFollower.follow]. The redirect chain itself is faked here —
 * plain Kotlin, no real HTTP.
 */
class MapsLinkResolverTest {

    @Test
    fun `resolves a share link that redirects to a place url`() {
        val follower = UrlRedirectFollower { "https://www.google.com/maps/place/Cal+Ferran/@41.98,2.82,17z" }

        val place = resolveMapsLink("https://share.google/kQaLED4YGoeSXDuB7", follower)

        assertEquals("Cal Ferran", place?.name)
        assertEquals("https://www.google.com/maps/place/Cal+Ferran/@41.98,2.82,17z", place?.resolvedUrl)
    }

    @Test
    fun `accepts the older maps app goo gl short link too`() {
        val follower = UrlRedirectFollower { "https://maps.google.com/maps/place/Bar+Del+Pla/@41.38,2.17,17z" }

        val place = resolveMapsLink("https://maps.app.goo.gl/abc123", follower)

        assertEquals("Bar Del Pla", place?.name)
    }

    @Test
    fun `decodes a percent-encoded place name`() {
        val follower = UrlRedirectFollower { "https://www.google.com/maps/place/Caf%C3%A9+del+Mar/@41.0,2.0,17z" }

        val place = resolveMapsLink("https://share.google/xyz", follower)

        assertEquals("Café del Mar", place?.name)
    }

    @Test
    fun `resolves to null place name when the final url has no place segment`() {
        val follower = UrlRedirectFollower { "https://www.google.com/maps/@41.98,2.82,17z" }

        val place = resolveMapsLink("https://share.google/xyz", follower)

        assertNull(place?.name)
        assertEquals("https://www.google.com/maps/@41.98,2.82,17z", place?.resolvedUrl)
    }

    @Test
    fun `refuses a host outside the google maps allowlist without following it`() {
        val follower = UrlRedirectFollower { error("should never be called") }

        assertNull(resolveMapsLink("https://evil.example.com/kQaLED4YGoeSXDuB7", follower))
    }

    @Test
    fun `returns null rather than throwing when the url is malformed`() {
        val follower = UrlRedirectFollower { error("should never be called") }

        assertNull(resolveMapsLink("not a url", follower))
    }

    @Test
    fun `returns null when the redirect chain fails`() {
        val follower = UrlRedirectFollower { null }

        assertNull(resolveMapsLink("https://share.google/kQaLED4YGoeSXDuB7", follower))
    }

    @Test
    fun `returns null when the follower throws`() {
        val follower = UrlRedirectFollower { throw java.io.IOException("timeout") }

        assertNull(resolveMapsLink("https://share.google/kQaLED4YGoeSXDuB7", follower))
    }
}
