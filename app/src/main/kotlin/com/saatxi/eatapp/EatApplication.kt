package com.saatxi.eatapp

import android.app.Application
import com.saatxi.eatapp.data.local.buildEatAppDatabase
import com.saatxi.eatapp.data.prefs.DataStoreUserPreferencesRepository
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.data.repository.RoomRestaurantRepository
import com.saatxi.eatapp.data.sync.RestaurantDatabaseSyncManager

class EatApplication : Application() {

    val repository: RestaurantRepository by lazy {
        RoomRestaurantRepository(buildEatAppDatabase(this).restaurantDao())
    }

    val syncManager: RestaurantDatabaseSyncManager by lazy {
        RestaurantDatabaseSyncManager(applicationContext, repository)
    }

    val userPreferences: UserPreferencesRepository by lazy {
        DataStoreUserPreferencesRepository(applicationContext)
    }
}
