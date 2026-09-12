package com.saatxi.eatapp.ui.map

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
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.common.cuisineTint
import com.saatxi.eatapp.ui.list.EmptyState
import com.saatxi.eatapp.ui.model.RestaurantUiModel
import org.osmdroid.tileprovider.tilesource.XYTileSource
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

/** Zoom level used when only a single pin is on-screen — a bounding box can't fit around one point. */
private const val SINGLE_PIN_ZOOM = 15.0

/**
 * CartoDB Positron: a light, low-saturation basemap (thin grey streets, muted
 * labels) — reads much better as a backdrop for the app's own coloured pins
 * than OSM's own default Mapnik style, which is busy and heavily saturated.
 * Same osmdroid tile-fetch machinery, just a different tile server; free for
 * non-commercial use with attribution, which the copyright string here covers.
 */
private val CARTO_POSITRON_TILE_SOURCE = XYTileSource(
    "CartoDBPositron",
    0,
    20,
    256,
    ".png",
    arrayOf(
        "https://a.basemaps.cartocdn.com/light_all/",
        "https://b.basemaps.cartocdn.com/light_all/",
        "https://c.basemaps.cartocdn.com/light_all/",
        "https://d.basemaps.cartocdn.com/light_all/"
    ),
    "© OpenStreetMap contributors © CARTO"
)

/** Extra room (px) left around the tightest bounding box that fits every pin, so edge markers aren't clipped by the view's border. */
private const val BOUNDING_BOX_PADDING_PX = 48

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
    val mapView = remember { MapView(context).apply { setTileSource(CARTO_POSITRON_TILE_SOURCE); setMultiTouchControls(true) } }

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
            view.overlays.clear()
            val points = pinned.mapNotNull { restaurant ->
                val lat = restaurant.latitude ?: return@mapNotNull null
                val lng = restaurant.longitude ?: return@mapNotNull null
                val point = GeoPoint(lat, lng)
                view.overlays.add(
                    Marker(view).apply {
                        position = point
                        title = restaurant.name
                        icon = ContextCompat.getDrawable(context, org.osmdroid.library.R.drawable.marker_default)
                            ?.mutate()
                            ?.apply { markerColors[restaurant.id]?.let(::setTint) }
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
