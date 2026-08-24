package com.albertferran.eatapp

import android.app.Application
import com.albertferran.eatapp.data.local.EatAppDatabase
import com.albertferran.eatapp.data.repository.RestaurantRepository
import com.albertferran.eatapp.data.repository.RoomRestaurantRepository

class EatApplication : Application() {

    val repository: RestaurantRepository by lazy {
        RoomRestaurantRepository(EatAppDatabase.getInstance(this).restaurantDao())
    }
}
