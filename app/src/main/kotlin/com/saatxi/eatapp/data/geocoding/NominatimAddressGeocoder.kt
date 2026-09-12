package com.saatxi.eatapp.data.geocoding

import android.util.Log
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

private const val TAG = "EatApp.Geocoding"
private const val CONNECT_TIMEOUT_MS = 10_000
private const val READ_TIMEOUT_MS = 10_000

/**
 * OpenStreetMap's own free geocoder — same data source as the Map screen's
 * tiles, so no separate API key. Its usage policy
 * (https://operations.osmfoundation.org/policies/nominatim/) requires a
 * distinct, identifying User-Agent on every request and asks for at most
 * ~1 request/second; this is fine for an on-demand, one-tap lookup a user
 * triggers by hand from the edit form, never called in a loop or on a timer.
 */
class NominatimAddressGeocoder @Inject constructor() : AddressGeocoder {

    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun geocode(query: String): GeocodeResult? {
        val trimmed = query.trim()
        if (trimmed.isBlank()) return null
        return withContext(Dispatchers.IO) {
            val encoded = URLEncoder.encode(trimmed, "UTF-8")
            val url = URL("https://nominatim.openstreetmap.org/search?format=json&limit=1&q=$encoded")
            val connection = url.openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = CONNECT_TIMEOUT_MS
                connection.readTimeout = READ_TIMEOUT_MS
                connection.setRequestProperty("User-Agent", "EatApp (Android, local-only restaurant journal)")
                if (connection.responseCode != HttpURLConnection.HTTP_OK) return@withContext null
                val body = connection.inputStream.bufferedReader().use { it.readText() }
                val results = json.decodeFromString(ListSerializer(NominatimResult.serializer()), body)
                results.firstOrNull()?.toGeocodeResultOrNull()
            } catch (e: IOException) {
                Log.w(TAG, "Geocoding request failed", e)
                null
            } catch (e: SerializationException) {
                Log.w(TAG, "Geocoding response could not be parsed", e)
                null
            } finally {
                connection.disconnect()
            }
        }
    }
}

/** One row of Nominatim's `/search` response — only the fields this app reads. */
@Serializable
private data class NominatimResult(val lat: String, val lon: String) {
    fun toGeocodeResultOrNull(): GeocodeResult? {
        val latitude = lat.toDoubleOrNull() ?: return null
        val longitude = lon.toDoubleOrNull() ?: return null
        return GeocodeResult(latitude, longitude)
    }
}
