package com.albertferran.eatapp.data.sync

/**
 * Validation for the two optional link columns of the synced `.db`.
 *
 * These values end up in an `Intent.ACTION_VIEW`, so a hand-edited — or
 * hostile — data file could otherwise hand the system a `javascript:`,
 * `intent:` or `file:` URI and have the app launch it. Everything here is a
 * whitelist: a value that isn't recognisably safe becomes null rather than
 * being passed through.
 *
 * Deliberately free of Android imports so the rules can be tested as plain
 * Kotlin, without a Robolectric runtime.
 */

/** Schemes the app is willing to hand to the system browser. */
private val ALLOWED_WEB_SCHEMES = setOf("http", "https")

private val SCHEME_PREFIX = Regex("^[A-Za-z][A-Za-z0-9+.-]*:")

/**
 * Instagram's own rules: letters, digits, periods and underscores, up to 30
 * characters. Constraining the handle this tightly is what makes scheme
 * injection structurally impossible — the URL is built from it, never parsed
 * out of the file.
 */
private val INSTAGRAM_HANDLE = Regex("^[A-Za-z0-9._]{1,30}$")

/** Base for [instagramUrl]; the handle is appended verbatim after validation. */
private const val INSTAGRAM_BASE_URL = "https://instagram.com/"

/**
 * Normalises a website value, or returns null if it isn't a plain web URL.
 *
 * A value with no scheme at all is assumed to be `https://` — data files
 * written by hand tend to hold bare hosts like `example.com`, and refusing
 * those would be pedantry rather than safety.
 */
fun normalizeWebsite(raw: String?): String? {
    val value = raw?.trim().orEmpty()
    if (value.isEmpty()) return null

    val scheme = SCHEME_PREFIX.find(value)?.value?.dropLast(1)?.lowercase()
        ?: return "https://$value"

    return if (scheme in ALLOWED_WEB_SCHEMES) value else null
}

/**
 * Normalises an Instagram value to a bare handle, or returns null.
 *
 * Accepts the handle with or without a leading `@`, which is how people write
 * it. A full URL is rejected: storing the handle keeps the app in control of
 * the URL it eventually opens.
 */
fun normalizeInstagramHandle(raw: String?): String? {
    val handle = raw?.trim()?.removePrefix("@").orEmpty()
    return handle.takeIf { INSTAGRAM_HANDLE.matches(it) }
}

/** The profile URL for a handle already validated by [normalizeInstagramHandle]. */
fun instagramUrl(handle: String): String = INSTAGRAM_BASE_URL + handle
