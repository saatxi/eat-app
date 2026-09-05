package com.saatxi.eatapp.widget

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.saatxi.eatapp.EatApplication
import com.saatxi.eatapp.MainActivity
import com.saatxi.eatapp.R
import com.saatxi.eatapp.data.local.Cuisine
import com.saatxi.eatapp.data.local.Restaurant

/** Read by [MainActivity] to jump straight to a restaurant's detail screen when the widget is tapped. */
const val EXTRA_RESTAURANT_ID = "com.saatxi.eatapp.widget.EXTRA_RESTAURANT_ID"

// Glance can't read the in-app Compose theme (palette choice, dynamic light/dark) — see
// colors.xml's comment; these resolve day/night through the values/values-night resource
// qualifiers instead, the same mechanism the rest of the app's XML (themes.xml, the
// widget's own initial layout) already uses. The `ColorProvider(@ColorRes Int)` overload
// is genuinely public and works correctly at runtime; lint's RestrictedApi flags it anyway
// (still marked library-internal in Glance 1.2.0's annotations), which is a lint/annotation
// gap rather than a real restriction — there is no public day/night-pair constructor to
// use instead in this version. Suppressed rather than worked around with fixed, non-adaptive
// colors, which would be a real regression (no dark mode) for a false alarm.
@Suppress("RestrictedApi")
private val WidgetBackground = ColorProvider(R.color.widget_background)
@Suppress("RestrictedApi")
private val WidgetOnBackground = ColorProvider(R.color.widget_on_background)
@Suppress("RestrictedApi")
private val WidgetMuted = ColorProvider(R.color.widget_muted)
@Suppress("RestrictedApi")
private val WidgetAccent = ColorProvider(R.color.widget_accent)

/**
 * Home-screen widget (F-68): one random want-to-try restaurant. Deliberately
 * *not* the app's own Roulette result — that pick lives only in
 * `RouletteViewModel`'s in-memory state, which a separate widget process has
 * no way to read, and persisting it just for this would be a second source
 * of truth for what is otherwise disposable UI state. Refreshed on the
 * system's own schedule (`want_to_try_widget_info.xml`) or on demand via the
 * widget's own shuffle action; tapping the restaurant opens its detail
 * screen directly.
 */
class WantToTryWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val repository = (context.applicationContext as EatApplication).repository
        val restaurant = repository.getRandomWantToTry()

        provideContent {
            WidgetContent(context, restaurant)
        }
    }
}

@Composable
private fun WidgetContent(context: Context, restaurant: Restaurant?) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(WidgetBackground)
            .appWidgetBackground()
            .padding(12.dp)
    ) {
        Text(
            text = context.getString(R.string.visit_status_want_to_try),
            style = TextStyle(color = WidgetMuted, fontSize = 11.sp)
        )
        Spacer(modifier = GlanceModifier.height(6.dp))

        if (restaurant == null) {
            Text(
                text = context.getString(R.string.widget_empty_body),
                style = TextStyle(color = WidgetOnBackground, fontSize = 14.sp)
            )
        } else {
            Column(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .defaultWeight()
                    .clickable(actionStartActivity(detailIntent(context, restaurant.id)))
            ) {
                Text(
                    text = restaurant.name,
                    maxLines = 1,
                    style = TextStyle(
                        color = WidgetOnBackground,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                )
                Text(
                    text = cuisineLabel(context, restaurant.cuisineType),
                    maxLines = 1,
                    style = TextStyle(color = WidgetMuted, fontSize = 13.sp)
                )
                restaurant.address?.let { address ->
                    Text(
                        text = address,
                        maxLines = 1,
                        style = TextStyle(color = WidgetMuted, fontSize = 12.sp)
                    )
                }
            }

            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Spacer(modifier = GlanceModifier.defaultWeight())
                Text(
                    text = context.getString(R.string.widget_action_shuffle),
                    style = TextStyle(
                        color = WidgetAccent,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    ),
                    modifier = GlanceModifier.clickable(actionRunCallback<ShuffleAction>())
                )
            }
        }
    }
}

/**
 * An explicit intent naming [MainActivity] directly, so it never goes through
 * that activity's own `ACTION_VIEW` intent-filters (those are for opening a
 * shared restaurant file, an unrelated flow) — [MainActivity] just reads
 * [EXTRA_RESTAURANT_ID] off whatever intent it was started with.
 */
private fun detailIntent(context: Context, restaurantId: Long): Intent =
    Intent(context, MainActivity::class.java).apply {
        putExtra(EXTRA_RESTAURANT_ID, restaurantId)
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
    }

/** Same lookup `cuisineLabel()` (ui/common/CuisineVisuals.kt) does, minus the Compose `stringResource` it needs. */
private fun cuisineLabel(context: Context, cuisineType: String): String =
    Cuisine.fromKey(cuisineType)?.let { context.getString(it.labelRes) } ?: cuisineType

/** Re-picks and re-renders without leaving the widget — the "shuffle" action. */
class ShuffleAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        WantToTryWidget().update(context, glanceId)
    }
}
