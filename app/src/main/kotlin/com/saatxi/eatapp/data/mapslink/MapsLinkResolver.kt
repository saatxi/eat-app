package com.saatxi.eatapp.data.mapslink

import java.net.HttpURLConnection
import java.net.URL
import java.net.URLDecoder
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Hosts a `share.google` link can be, or can redirect through, on its way to
 * a real Maps place page. Anything else is refused before any request is
 * made — this is the only network access in the app (see CLAUDE.md's
 * "Networking" section), and it must not become a general-purpose URL
 * opener.
 */
private val ALLOWED_HOSTS = setOf(
    "share.google",
    "maps.app.goo.gl",
    "goo.gl",
    "maps.google.com",
    "google.com",
    "www.google.com"
)

private const val CONNECT_TIMEOUT_MS = 5_000
private const val READ_TIMEOUT_MS = 5_000

/** Redirect hops to follow before giving up, rather than chasing a loop forever. */
private const val MAX_REDIRECTS = 5

/** What a resolved Google Maps link yields: the place name, if the URL's shape reveals one, and the final URL it redirected to. */
data class MapsPlace(val name: String?, val resolvedUrl: String)

/**
 * Follows a URL's redirect chain and returns the final URL, or null on any
 * failure. Isolated behind an interface so tests can fake the network call.
 */
fun interface UrlRedirectFollower {
    fun follow(url: String): String?
}

/** [UrlRedirectFollower] backed by [HttpURLConnection] — the app's one and only network call. */
object HttpUrlRedirectFollower : UrlRedirectFollower {
    override fun follow(url: String): String? {
        var current = url
        repeat(MAX_REDIRECTS) {
            val connection = URL(current).openConnection() as HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.requestMethod = "HEAD"
            try {
                val code = connection.responseCode
                val location = connection.getHeaderField("Location")
                if (code in 300..399 && location != null) {
                    current = location
                } else {
                    return current
                }
            } finally {
                connection.disconnect()
            }
        }
        return current
    }
}

/** Matches the place-name segment of a Maps URL, e.g. `/maps/place/Cal+Ferran/@41.9,2.8,17z`. */
private val PLACE_NAME_REGEX = Regex("/maps/place/([^/@]+)")

/**
 * Resolves a Google Maps share link into a [MapsPlace], or null if [url]'s
 * host isn't a recognised Google Maps host, or the redirect chain fails.
 * Never throws — a malformed or unreachable link degrades to null so the
 * caller can fall back to letting the user fill the form in manually.
 */
fun resolveMapsLink(url: String, follower: UrlRedirectFollower = HttpUrlRedirectFollower): MapsPlace? {
    val host = runCatching { URL(url).host }.getOrNull()?.lowercase() ?: return null
    if (ALLOWED_HOSTS.none { allowed -> host == allowed || host.endsWith(".$allowed") }) return null

    val resolved = runCatching { follower.follow(url) }.getOrNull() ?: return null
    val name = PLACE_NAME_REGEX.find(resolved)?.groupValues?.get(1)
        ?.replace('+', ' ')
        ?.let { encoded -> runCatching { URLDecoder.decode(encoded, "UTF-8") }.getOrDefault(encoded) }
        ?.trim()
        ?.takeIf { it.isNotEmpty() }

    return MapsPlace(name = name, resolvedUrl = resolved)
}

/** Thin, injectable wrapper around [resolveMapsLink] so ViewModels don't call the top-level function directly. */
class MapsLinkResolver @Inject constructor() {
    suspend fun resolve(url: String): MapsPlace? = withContext(Dispatchers.IO) {
        resolveMapsLink(url)
    }
}
