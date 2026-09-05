package com.saatxi.eatapp.widget

import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver

/** The system's entry point into the widget — see `AndroidManifest.xml`'s `<receiver>`. */
class WantToTryWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = WantToTryWidget()
}
