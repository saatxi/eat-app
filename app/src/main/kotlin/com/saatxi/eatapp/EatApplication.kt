package com.saatxi.eatapp

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

/**
 * Dependency wiring (database, repositories, locale manager) now lives in
 * Hilt modules under `di/` — see [com.saatxi.eatapp.di.AppModule]. This class
 * only needs the `@HiltAndroidApp` annotation to generate the app-level
 * dependency container that everything else attaches to.
 */
@HiltAndroidApp
class EatApplication : Application()
