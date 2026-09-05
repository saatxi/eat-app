package com.saatxi.eatapp.data.local

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * MIGRATION_8_9 (F-59) is the app's first migration involving foreign keys
 * and a composite primary key, and its hand-written SQL has to match Room's
 * own generated schema exactly since `exportSchema = false` leaves no schema
 * JSON to check it against. Room's runtime validation on open checks
 * column/index/foreign-key shape but *not* `COLLATE` — so a mistake in
 * `tags.name`'s `COLLATE NOCASE` wouldn't fail the open below at all; the
 * case-insensitivity assertion in the test is the only real safety net for
 * that specific mistake.
 *
 * The pre-migration `restaurants` table is built by hand from the exact SQL
 * Room itself generates for [Restaurant] (copied from a build's generated
 * `EatAppDatabase_Impl`, at a point before this migration existed — the
 * table's shape hasn't changed since), rather than a second Room database
 * class: that would need its own KSP-generated `_Impl`, which the test
 * source set isn't set up to produce.
 */
@RunWith(RobolectricTestRunner::class)
class MigrationTest {

    private lateinit var context: Context
    private val dbName = "migration-test.db"

    @After
    fun tearDown() {
        context.deleteDatabase(dbName)
    }

    @Test
    fun `MIGRATION_8_9 opens cleanly on a real version-8 database and dedupes tags case-insensitively`() = runTest {
        context = ApplicationProvider.getApplicationContext()
        val dbFile = context.getDatabasePath(dbName)

        // A v8-shaped database file on disk, standing in for an app that's
        // never been opened past version 8 — exactly what MIGRATION_8_9
        // will actually run against in the field.
        SQLiteDatabase.openOrCreateDatabase(dbFile, null).use { legacyDb ->
            legacyDb.execSQL(
                "CREATE TABLE IF NOT EXISTS `restaurants` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, " +
                    "`name` TEXT NOT NULL, `cuisineType` TEXT NOT NULL, `address` TEXT, `rating` INTEGER NOT NULL, " +
                    "`priceRange` INTEGER NOT NULL, `visited` INTEGER NOT NULL, `website` TEXT, `instagram` TEXT, " +
                    "`photoPath` TEXT, `notes` TEXT, `searchText` TEXT NOT NULL)"
            )
            legacyDb.execSQL("CREATE INDEX IF NOT EXISTS `index_restaurants_name` ON `restaurants` (`name`)")
            legacyDb.execSQL("CREATE INDEX IF NOT EXISTS `index_restaurants_rating` ON `restaurants` (`rating`)")
            legacyDb.execSQL("CREATE TABLE IF NOT EXISTS room_master_table (id INTEGER PRIMARY KEY,identity_hash TEXT)")
            legacyDb.execSQL(
                "INSERT INTO restaurants (id, name, cuisineType, address, rating, priceRange, visited, searchText) " +
                    "VALUES (1, 'Cal Ferran', 'mediterranean', NULL, 4, 2, 1, 'cal ferran mediterranean')"
            )
            legacyDb.version = 8
        }

        // Opened with no fallback: a schema mismatch throws here instead of
        // being silently papered over by `fallbackToDestructiveMigration`.
        val migrated = Room.databaseBuilder(context, EatAppDatabase::class.java, dbName)
            .allowMainThreadQueries()
            .addMigrations(MIGRATION_8_9)
            .build()

        val tagDao = migrated.tagDao()
        val restaurantId = migrated.restaurantDao().getAll().single().id

        tagDao.setTags(restaurantId, listOf("Terraza"))
        tagDao.setTags(restaurantId, listOf("terraza"))

        val allTagNames = tagDao.observeAllTagNames().first()
        assertEquals(listOf("Terraza"), allTagNames)

        migrated.close()
    }
}
