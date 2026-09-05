package com.saatxi.eatapp

import android.app.Application
import com.saatxi.eatapp.data.local.buildEatAppDatabase
import com.saatxi.eatapp.data.prefs.AppCompatLocaleManager
import com.saatxi.eatapp.data.prefs.AppLocaleManager
import com.saatxi.eatapp.data.prefs.DataStoreUserPreferencesRepository
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.data.repository.RoomRestaurantRepository

class EatApplication : Application() {

    val repository: RestaurantRepository by lazy {
        RoomRestaurantRepository(buildEatAppDatabase(this), applicationContext)
    }

    val userPreferences: UserPreferencesRepository by lazy {
        DataStoreUserPreferencesRepository(applicationContext)
    }

    val localeManager: AppLocaleManager by lazy {
        AppCompatLocaleManager()
    }
}
