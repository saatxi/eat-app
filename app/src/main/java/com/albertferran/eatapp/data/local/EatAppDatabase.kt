package com.albertferran.eatapp.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters

@Database(entities = [Restaurant::class], version = 1, exportSchema = false)
@TypeConverters(Converters::class)
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
                ).build().also { instance = it }
            }
    }
}
