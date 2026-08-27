package com.albertferran.eatapp.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [Restaurant::class], version = 4, exportSchema = false)
abstract class EatAppDatabase : RoomDatabase() {

    abstract fun restaurantDao(): RestaurantDao

    companion object {
        @Volatile
        private var instance: EatAppDatabase? = null

        fun getInstance(context: Context): EatAppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    EatAppDatabase::class.java,
                    "eatapp.db"
                )
                    // The local database is a pure cache of a re-downloadable .db file,
                    // so discarding it on a schema change and re-syncing is the correct
                    // behaviour rather than a shortcut.
                    .fallbackToDestructiveMigration(dropAllTables = true)
                    .build()
                    .also { instance = it }
            }
    }
}
