package com.saatxi.eatapp

import android.app.Application
import dagger.hilt.android.HiltAndroidApp
import org.osmdroid.config.Configuration

/**
 * Dependency wiring (database, repositories, locale manager) now lives in
 * Hilt modules under `di/` — see [com.saatxi.eatapp.di.AppModule]. This class
 * only needs the `@HiltAndroidApp` annotation to generate the app-level
 * dependency container that everything else attaches to.
 */
@HiltAndroidApp
class EatApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // osmdroid (Map screen, F-89) refuses to fetch tiles without a
        // distinct user agent — the OSM tile servers block the default one —
        // and defaults to a cache directory that needs a storage permission
        // this app otherwise never asks for; cacheDir is already private to
        // the app and needs none.
        Configuration.getInstance().apply {
            userAgentValue = packageName
            osmdroidBasePath = cacheDir.resolve("osmdroid")
            osmdroidTileCache = osmdroidBasePath.resolve("tiles")
        }
    }
}
