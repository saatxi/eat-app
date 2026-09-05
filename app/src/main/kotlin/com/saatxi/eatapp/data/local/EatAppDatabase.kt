package com.saatxi.eatapp.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(entities = [Restaurant::class], version = 8, exportSchema = false)
abstract class EatAppDatabase : RoomDatabase() {

    abstract fun restaurantDao(): RestaurantDao
}

/**
 * Adds [Restaurant.visited]. Existing rows default to `1` (visited) — the
 * app's only mode until now — except rows with no rating yet, which read as
 * a place noted down but never actually tried.
 */
private val MIGRATION_5_6 = object : Migration(5, 6) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE restaurants ADD COLUMN visited INTEGER NOT NULL DEFAULT 1")
        db.execSQL("UPDATE restaurants SET visited = 0 WHERE rating = 0")
    }
}

/** Adds [Restaurant.photoPath] (F-63). Nullable with no default, so every existing row reads back with no photo. */
private val MIGRATION_6_7 = object : Migration(6, 7) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE restaurants ADD COLUMN photoPath TEXT")
    }
}

/** Adds [Restaurant.notes] (F-56). Nullable with no default, so every existing row reads back with no note. */
private val MIGRATION_7_8 = object : Migration(7, 8) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE restaurants ADD COLUMN notes TEXT")
    }
}

fun buildEatAppDatabase(context: Context): EatAppDatabase =
    Room.databaseBuilder(
        context.applicationContext,
        EatAppDatabase::class.java,
        "eatapp.db"
    )
        .addMigrations(MIGRATION_5_6, MIGRATION_6_7, MIGRATION_7_8)
        // The restaurants here are entered by hand and not recoverable from
        // anywhere else, unlike the old re-downloadable .db cache this used to
        // hold. The next time `version` changes, this MUST be replaced with a
        // real Migration — falling back to this would silently delete every
        // restaurant the user has ever added.
        .fallbackToDestructiveMigration(dropAllTables = true)
        .build()
