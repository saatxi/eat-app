package com.saatxi.eatapp.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [Restaurant::class, Tag::class, RestaurantTag::class, Visit::class, Photo::class],
    version = 14,
    exportSchema = true
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
        // The app now has real production users, so version 14 (exported to
        // app/schemas/) is a frozen baseline: every future @Database version
        // bump MUST ship a real Migration (added below via .addMigrations(...))
        // that preserves existing rows, checked against that schema history in
        // MigrationTest. There is deliberately no destructive-on-upgrade
        // fallback any more — a missing Migration should crash loudly at
        // startup instead of silently wiping the user's restaurants, which is
        // what used to happen here (see the git history of this file).
        // Downgrading (installing an older APK over a newer database) is the
        // one case with no real fix, so that alone still falls back
        // destructively.
        .fallbackToDestructiveMigrationOnDowngrade(dropAllTables = true)
        .build()
