package com.saatxi.eatapp.data.local

import android.content.Context
import androidx.room.Room
import androidx.room.testing.MigrationTestHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.robolectric.RobolectricTestRunner
import org.junit.runner.RunWith

/**
 * The app now has real production users (see the comment on
 * `buildEatAppDatabase` in `EatAppDatabase.kt`), so a schema bump with no
 * matching `Migration` must fail loudly instead of silently wiping data via a
 * destructive fallback. Version 14's exported schema (`app/schemas/`) is the
 * frozen baseline every future migration is tested against here: once a real
 * `Migration` is written for the next version bump, this file is where its
 * regression test belongs, following Room's `MigrationTestHelper` pattern
 * used in this test.
 */
@RunWith(RobolectricTestRunner::class)
class MigrationTest {

    @get:Rule
    val helper: MigrationTestHelper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        EatAppDatabase::class.java
    )

    @Test
    fun `reopening a version 14 database does not delete its data`() = runTest {
        val context: Context = ApplicationProvider.getApplicationContext()
        val dbName = context.getDatabasePath("migration-test.db").absolutePath
        helper.createDatabase(dbName, 14).apply {
            execSQL(
                "INSERT INTO restaurants (id, name, cuisineType, address, priceRange, searchText) " +
                    "VALUES ('r1', 'Test', 'japanese', NULL, 2, 'test')"
            )
            close()
        }

        // Room.databaseBuilder (unlike MigrationTestHelper) has no migrations
        // registered and, as of this app's fix for the "update wipes all
        // restaurants" bug, no destructive-on-upgrade fallback either: opening
        // the same version must reuse the existing file and its rows rather
        // than recreating it from scratch.
        val reopened = Room.databaseBuilder(context, EatAppDatabase::class.java, dbName)
            .openHelperFactory(FrameworkSQLiteOpenHelperFactory())
            .allowMainThreadQueries()
            .build()
        assertTrue(reopened.restaurantDao().getAll().isNotEmpty())
        reopened.close()

        context.deleteDatabase("migration-test.db")
    }
}
