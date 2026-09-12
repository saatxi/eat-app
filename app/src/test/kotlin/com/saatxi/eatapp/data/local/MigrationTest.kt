package com.saatxi.eatapp.data.local

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The old hand-written MIGRATION_8_9/MIGRATION_9_10 regression tests are gone:
 * this pass's schema jump (client-generated String ids, the Restaurant ->
 * Visit/Photo split) is a destructive one — see `EatAppDatabase.kt` — since
 * there are no production users yet to preserve data for. There is no new
 * `Migration` to test. What's left is a much smaller smoke test: a database
 * that predates this schema still opens (destructively) rather than crashing.
 */
@RunWith(RobolectricTestRunner::class)
class MigrationTest {

    private val dbName = "migration-test.db"
    private lateinit var context: Context

    @After
    fun tearDown() {
        context.deleteDatabase(dbName)
    }

    @Test
    fun `an old-shaped database file opens cleanly via destructive fallback`() = runTest {
        context = ApplicationProvider.getApplicationContext()
        val dbFile = context.getDatabasePath(dbName)

        android.database.sqlite.SQLiteDatabase.openOrCreateDatabase(dbFile, null).use { legacyDb ->
            legacyDb.execSQL(
                "CREATE TABLE IF NOT EXISTS `restaurants` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, " +
                    "`name` TEXT NOT NULL, `cuisineType` TEXT NOT NULL, `address` TEXT, `rating` INTEGER NOT NULL, " +
                    "`priceRange` INTEGER NOT NULL, `visited` INTEGER NOT NULL, `searchText` TEXT NOT NULL)"
            )
            legacyDb.execSQL("CREATE TABLE IF NOT EXISTS room_master_table (id INTEGER PRIMARY KEY,identity_hash TEXT)")
            legacyDb.version = 8
        }

        val migrated = Room.databaseBuilder(context, EatAppDatabase::class.java, dbName)
            .allowMainThreadQueries()
            .fallbackToDestructiveMigration(dropAllTables = true)
            .build()
        assertTrue(migrated.restaurantDao().getAll().isEmpty())
        migrated.close()
    }
}
