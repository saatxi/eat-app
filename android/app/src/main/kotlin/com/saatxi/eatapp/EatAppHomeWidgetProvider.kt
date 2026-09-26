package com.saatxi.eatapp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The "Want to try" home-screen widget.
 *
 * Deliberately dumb: every string it draws — the header, the restaurant's name
 * and cuisine, the empty-state message and the shuffle label — is written into
 * the widget's `SharedPreferences` by the Dart side
 * (`lib/widget/home_widget_service.dart`), which is the only place that knows
 * what a want-to-try restaurant is or how to translate a cuisine. This class
 * only lays those values out and wires up the two taps.
 *
 * The keys below are mirrored in `HomeWidgetKeys` on the Dart side; the two have
 * to stay in step.
 */
class EatAppHomeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val restaurantId = widgetData.getString(KEY_RESTAURANT_ID, "").orEmpty()
        val title = widgetData.getString(KEY_TITLE, "").orEmpty()
        val subtitle = widgetData.getString(KEY_SUBTITLE, "").orEmpty()
        val label = widgetData.getString(KEY_LABEL, "").orEmpty()
        val empty = widgetData.getString(KEY_EMPTY, "").orEmpty()
        val shuffle = widgetData.getString(KEY_SHUFFLE, "").orEmpty()
        val hasPick = title.isNotBlank()

        appWidgetIds.forEach { appWidgetId ->
            val views =
                RemoteViews(context.packageName, R.layout.eatapp_home_widget).apply {
                    setTextViewText(R.id.widget_label, label)

                    if (hasPick) {
                        setTextViewText(R.id.widget_title, title)
                        if (subtitle.isBlank()) {
                            setViewVisibility(R.id.widget_subtitle, View.GONE)
                        } else {
                            setViewVisibility(R.id.widget_subtitle, View.VISIBLE)
                            setTextViewText(R.id.widget_subtitle, subtitle)
                        }

                        // Tapping the shuffle button runs the Dart callback in
                        // the background, which picks a new restaurant and
                        // republishes the widget — no need to open the app.
                        setViewVisibility(R.id.widget_shuffle, View.VISIBLE)
                        setContentDescription(R.id.widget_shuffle, shuffle)
                        setOnClickPendingIntent(
                            R.id.widget_shuffle,
                            HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                Uri.parse(SHUFFLE_LINK),
                            ),
                        )

                        // Tapping the card itself opens that restaurant's
                        // detail screen; the app resolves the id from the link.
                        setOnClickPendingIntent(
                            R.id.widget_container,
                            HomeWidgetLaunchIntent.getActivity(
                                context,
                                MainActivity::class.java,
                                Uri.parse("$RESTAURANT_LINK_PREFIX/$restaurantId"),
                            ),
                        )
                    } else {
                        // Nothing to try: the header stays, the body explains
                        // what to do, and there is nothing to shuffle.
                        setTextViewText(R.id.widget_title, empty)
                        setViewVisibility(R.id.widget_subtitle, View.GONE)
                        setViewVisibility(R.id.widget_shuffle, View.GONE)
                        setOnClickPendingIntent(
                            R.id.widget_container,
                            HomeWidgetLaunchIntent.getActivity(
                                context,
                                MainActivity::class.java,
                            ),
                        )
                    }
                }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private companion object {
        const val KEY_RESTAURANT_ID = "restaurantId"
        const val KEY_TITLE = "title"
        const val KEY_SUBTITLE = "subtitle"
        const val KEY_LABEL = "label"
        const val KEY_EMPTY = "empty"
        const val KEY_SHUFFLE = "shuffle"

        const val SHUFFLE_LINK = "eatapp://shuffle"
        const val RESTAURANT_LINK_PREFIX = "eatapp://restaurant"
    }
}
