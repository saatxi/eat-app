package com.albertferran.eatapp

import android.app.Application
import com.albertferran.eatapp.data.local.EatAppDatabase
import com.albertferran.eatapp.data.repository.RestaurantRepository
import com.albertferran.eatapp.data.repository.RoomRestaurantRepository
import com.albertferran.eatapp.data.sync.RestaurantDatabaseSyncManager

class EatApplication : Application() {

    val repository: RestaurantRepository by lazy {
        RoomRestaurantRepository(EatAppDatabase.getInstance(this).restaurantDao())
    }

    val syncManager: RestaurantDatabaseSyncManager by lazy {
        RestaurantDatabaseSyncManager(applicationContext, repository)
    }
}
