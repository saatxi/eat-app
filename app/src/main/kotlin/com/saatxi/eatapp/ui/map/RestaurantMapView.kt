package com.saatxi.eatapp.ui.map

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.drawable.BitmapDrawable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Map
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.saatxi.eatapp.BuildConfig
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.common.cuisineTint
import com.saatxi.eatapp.ui.list.EmptyState
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import org.osmdroid.tileprovider.tilesource.ITileSource
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.tileprovider.tilesource.XYTileSource
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.CopyrightOverlay
import org.osmdroid.views.overlay.Marker

/** Zoom level used when only a single pin is on-screen — a bounding box can't fit around one point. */
private const val SINGLE_PIN_ZOOM = 15.0

/**
 * CARTO Voyager: a clean, low-saturation basemap — reads much better as a
 * backdrop for the app's own coloured pins than OSM's own default Mapnik
 * style, which is busy and heavily saturated. Requires a personal CARTO API
 * key (free up to 5,000,000 tile requests/month) — see [BuildConfig.CARTO_API_KEY]
 * and `app/build.gradle.kts`'s "Map tiles" section for where that key comes
 * from and why it's never committed. Attribution (CARTO's key terms require
 * it stay visible — see carto.com/attributions) lives in the copyright
 * string below, which osmdroid is responsible for actually drawing.
 */
private fun cartoVoyagerTileSource(apiKey: String) = XYTileSource(
    "CartoDBVoyager",
    0,
    20,
    256,
    ".png?key=$apiKey",
    arrayOf("https://basemaps.cartocdn.com/rastertiles/voyager/"),
    "© OpenStreetMap contributors © CARTO"
)

/** No CARTO key configured (e.g. a fresh checkout without local.properties set up) — falls back to OSM's own tiles, which need none, over a broken/watermarked map. */
private fun defaultTileSource(): ITileSource = TileSourceFactory.MAPNIK

private fun mapTileSource(): ITileSource =
    BuildConfig.CARTO_API_KEY.takeIf { it.isNotBlank() }?.let(::cartoVoyagerTileSource) ?: defaultTileSource()

/** Extra room (px) left around the tightest bounding box that fits every pin, so edge markers aren't clipped by the view's border. */
private const val BOUNDING_BOX_PADDING_PX = 48

/** Marker pin diameter — a plain filled circle reads much cleaner at map scale than osmdroid's stock oversized teardrop marker. */
private const val PIN_DIAMETER_DP = 28

/**
 * Draws a small filled, white-bordered circle in [colorArgb] — the same
 * per-cuisine colour used everywhere else in the app — as this restaurant's
 * pin, instead of osmdroid's default `marker_default` teardrop (a generic,
 * oversized pin never designed to be recoloured per-marker). Centered
 * anchoring (set on the [Marker] itself, not here) matches a plain dot
 * rather than a teardrop's bottom-tip anchoring.
 */
private fun pinDrawable(context: android.content.Context, colorArgb: Int): BitmapDrawable {
    val density = context.resources.displayMetrics.density
    val diameterPx = (PIN_DIAMETER_DP * density).toInt().coerceAtLeast(1)
    val strokeWidthPx = 2f * density
    val bitmap = Bitmap.createBitmap(diameterPx, diameterPx, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val center = diameterPx / 2f
    val radius = center - strokeWidthPx
    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colorArgb; style = Paint.Style.FILL }
    val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE
        style = Paint.Style.STROKE
        strokeWidth = strokeWidthPx
    }
    canvas.drawCircle(center, center, radius, fillPaint)
    canvas.drawCircle(center, center, radius, strokePaint)
    return BitmapDrawable(context.resources, bitmap)
}

/**
 * The Map screen's content (F-89): one pin per restaurant that has a
 * latitude/longitude set (most won't, until the user fills those in on the
 * edit form — see [RestaurantUiModel.latitude]), tinted the same per-cuisine
 * colour as everywhere else in the app ([cuisineTint]). Pans/zooms to fit
 * every pinned restaurant whenever the set of pins changes; a restaurant
 * with no coordinates simply never appears here — the empty state only
 * shows when *none* of [restaurants] have one, not for an empty
 * [restaurants] list itself (that's the caller's own empty/loading state).
 */
@Composable
fun RestaurantMapView(
    restaurants: List<RestaurantUiModel>,
    onOpenRestaurant: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val pinned = remember(restaurants) { restaurants.filter { it.latitude != null && it.longitude != null } }

    if (pinned.isEmpty()) {
        EmptyState(
            icon = Icons.Outlined.Map,
            title = stringResource(R.string.map_empty_title),
            body = stringResource(R.string.map_empty_body),
            modifier = modifier.fillMaxSize()
        )
        return
    }

    val context = LocalContext.current
    // cuisineTint is @Composable (reads MaterialTheme), so every marker's colour
    // is resolved here, up front, rather than from inside the AndroidView update
    // block below, which runs outside composition.
    val markerColors = pinned.associate { it.id to cuisineTint(it.cuisineKey).container.toArgb() }
    val lifecycleOwner = LocalLifecycleOwner.current
    val mapView = remember {
        MapView(context).apply {
            val tileSource = mapTileSource()
            setTileSource(tileSource)
            setMultiTouchControls(true)
            // CARTO's free-tier key terms require this attribution stay visible on
            // the map (carto.com/attributions) — osmdroid never draws a tile
            // source's copyright notice on its own, only this overlay does.
            overlays.add(CopyrightOverlay(context).apply { setCopyrightNotice(tileSource.copyrightNotice) })
        }
    }

    // osmdroid's MapView owns background tile-fetch threads that must be paused
    // and resumed with the host lifecycle, or they keep running (and the tile
    // cache keeps growing) while this screen isn't visible; onDetach releases
    // them for good once the composable itself leaves composition.
    DisposableEffect(lifecycleOwner, mapView) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            mapView.onDetach()
        }
    }

    AndroidView(
        factory = { mapView },
        update = { view ->
            // Only markers get rebuilt on every update — the CopyrightOverlay added
            // once in `factory` above must stay, or the required attribution vanishes.
            view.overlays.removeAll { it is Marker }
            val points = pinned.mapNotNull { restaurant ->
                val lat = restaurant.latitude ?: return@mapNotNull null
                val lng = restaurant.longitude ?: return@mapNotNull null
                val point = GeoPoint(lat, lng)
                view.overlays.add(
                    Marker(view).apply {
                        position = point
                        title = restaurant.name
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                        icon = pinDrawable(context, markerColors[restaurant.id] ?: AndroidColor.GRAY)
                        setOnMarkerClickListener { _, _ ->
                            onOpenRestaurant(restaurant.id)
                            true
                        }
                    }
                )
                point
            }
            if (points.size == 1) {
                view.controller.setZoom(SINGLE_PIN_ZOOM)
                view.controller.setCenter(points.first())
            } else {
                view.zoomToBoundingBox(BoundingBox.fromGeoPointsSafe(points), false, BOUNDING_BOX_PADDING_PX)
            }
            view.invalidate()
        },
        modifier = modifier.fillMaxSize()
    )
}
