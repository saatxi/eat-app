package com.saatxi.eatapp.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [Restaurant::class, Tag::class, RestaurantTag::class, Visit::class, Photo::class],
    version = 14,
    exportSchema = false
)
abstract class EatAppDatabase : RoomDatabase() {

    abstract fun restaurantDao(): RestaurantDao
    abstract fun tagDao(): TagDao
    abstract fun visitDao(): VisitDao
    abstract fun photoDao(): PhotoDao
}

fun buildEatAppDatabase(context: Context): EatAppDatabase =
    Room.databaseBuilder(
        context.applicationContext,
        EatAppDatabase::class.java,
        "eatapp.db"
    )
        // This is a pre-release app with no production users yet, and the id
        // type itself changed (Long autoincrement -> client-generated UUID
        // String) along with the relational split of rating/visited/notes/photo
        // into Visit/Photo — there is no meaningful in-place migration to write
        // for that. Once real user data exists, this MUST be replaced with a
        // real Migration before the next schema bump.
        .fallbackToDestructiveMigration(dropAllTables = true)
        .build()
