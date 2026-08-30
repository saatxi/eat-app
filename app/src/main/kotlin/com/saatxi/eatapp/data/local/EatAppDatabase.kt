package com.saatxi.eatapp.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [Restaurant::class], version = 5, exportSchema = false)
abstract class EatAppDatabase : RoomDatabase() {

    abstract fun restaurantDao(): RestaurantDao
}

fun buildEatAppDatabase(context: Context): EatAppDatabase =
    Room.databaseBuilder(
        context.applicationContext,
        EatAppDatabase::class.java,
        "eatapp.db"
    )
        // The restaurants here are entered by hand and not recoverable from
        // anywhere else, unlike the old re-downloadable .db cache this used to
        // hold. The next time `version` changes, this MUST be replaced with a
        // real Migration — falling back to this would silently delete every
        // restaurant the user has ever added.
        .fallbackToDestructiveMigration(dropAllTables = true)
        .build()
