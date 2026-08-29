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
        // The local database is a pure cache of a re-downloadable .db file, so
        // discarding it on a schema change and re-syncing is the correct
        // behaviour rather than a shortcut.
        .fallbackToDestructiveMigration(dropAllTables = true)
        .build()
