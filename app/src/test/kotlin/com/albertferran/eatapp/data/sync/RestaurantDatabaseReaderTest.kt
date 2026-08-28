package com.albertferran.eatapp.data.sync

import android.database.sqlite.SQLiteDatabase
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The downloaded `.db` is untrusted input, and this validation is the only
 * thing standing between a hand-edited data file and a crash (F-01, F-02).
 */
@RunWith(RobolectricTestRunner::class)
class RestaurantDatabaseReaderTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private fun databaseWith(
        schema: String = FULL_SCHEMA,
        populate: SQLiteDatabase.() -> Unit = {}
    ): File {
        val file = File(tempFolder.root, "source-${System.nanoTime()}.db")
        val db = SQLiteDatabase.openOrCreateDatabase(file, null)
        db.execSQL(schema)
        db.populate()
        db.close()
        return file
    }

    private fun SQLiteDatabase.insertRow(
        id: Long = 1,
        name: String? = "Cal Ferran",
        cuisineType: String? = "mediterranean",
        address: String? = "Placa Santa Anna, Mataro",
        rating: Int = 4,
        priceRange: Int = 2
    ) {
        execSQL(
            "INSERT INTO restaurants VALUES (?, ?, ?, ?, ?, ?)",
            arrayOf<Any?>(id, name, cuisineType, address, rating, priceRange)
        )
    }

    private fun readErrorOf(file: File): DatabaseSyncResult.Failure {
        val outcome = RestaurantDatabaseReader.read(file)
        assertTrue("expected an error, got $outcome", outcome is ReadOutcome.Error)
        return (outcome as ReadOutcome.Error).failure
    }

    private fun readRowsOf(file: File) =
        (RestaurantDatabaseReader.read(file) as ReadOutcome.Rows).restaurants

    // --- happy path ---------------------------------------------------------

    @Test
    fun `reads a well-formed row`() {
        val rows = readRowsOf(databaseWith { insertRow() })

        assertEquals(1, rows.size)
        val restaurant = rows.single()
        assertEquals(1L, restaurant.id)
        assertEquals("Cal Ferran", restaurant.name)
        assertEquals("mediterranean", restaurant.cuisineType)
        assertEquals("Placa Santa Anna, Mataro", restaurant.address)
        assertEquals(4, restaurant.rating)
        assertEquals(2, restaurant.priceRange)
    }

    @Test
    fun `derives the normalized search text on import`() {
        val rows = readRowsOf(
            databaseWith {
                insertRow(name = "Cafe Niló", address = "Plaça Gran")
            }
        )
        // F-14: the column is derived here, never read from the file.
        assertTrue(rows.single().searchText.contains("cafe nilo"))
        assertTrue(rows.single().searchText.contains("placa gran"))
    }

    @Test
    fun `treats address as genuinely optional`() {
        val rows = readRowsOf(databaseWith { insertRow(address = null) })

        assertNull(rows.single().address)
    }

    @Test
    fun `reads every row`() {
        val rows = readRowsOf(
            databaseWith {
                insertRow(id = 1, name = "One")
                insertRow(id = 2, name = "Two")
                insertRow(id = 3, name = "Three")
            }
        )
        assertEquals(listOf("One", "Two", "Three"), rows.map { it.name })
    }

    // --- schema validation --------------------------------------------------

    @Test
    fun `ignores columns it no longer needs`() {
        // Data files written before notes, createdAt, visitDate and photoUri were
        // dropped must keep importing: the reader names the columns it selects and
        // only requires REQUIRED_COLUMNS to be present, never that the set matches
        // exactly.
        val file = databaseWith(schema = SCHEMA_WITH_DROPPED_COLUMNS) {
            execSQL(
                "INSERT INTO restaurants VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                arrayOf<Any?>(1L, "Cal Ferran", "mediterranean", null, 4, 2, "Great paella", 20_000L, null, 1_700_000_000L)
            )
        }

        val rows = readRowsOf(file)

        assertEquals("Cal Ferran", rows.single().name)
        assertEquals("mediterranean", rows.single().cuisineType)
    }

    @Test
    fun `rejects a file missing a required column`() {
        val failure = readErrorOf(databaseWith(schema = SCHEMA_WITHOUT_CUISINE))

        assertEquals(SyncFailureReason.INVALID_FILE, failure.reason)
        assertTrue("detail should name the column: ${failure.detail}", failure.detail!!.contains("cuisineType"))
    }

    @Test
    fun `rejects a file with no restaurants table at all`() {
        val failure = readErrorOf(databaseWith(schema = "CREATE TABLE other (id INTEGER)"))

        assertEquals(SyncFailureReason.INVALID_FILE, failure.reason)
    }

    @Test
    fun `rejects bytes that are not a SQLite database`() {
        val file = tempFolder.newFile("garbage.db")
        file.writeBytes(ByteArray(64) { it.toByte() })

        val failure = readErrorOf(file)

        assertEquals(SyncFailureReason.INVALID_FILE, failure.reason)
        assertTrue("detail should blame the header: ${failure.detail}", failure.detail!!.contains("header"))
    }

    @Test
    fun `rejects a file too short to hold a SQLite header`() {
        val file = tempFolder.newFile("truncated.db")
        file.writeBytes("SQLite".toByteArray())

        val failure = readErrorOf(file)

        assertEquals(SyncFailureReason.INVALID_FILE, failure.reason)
        assertTrue("detail should blame the header: ${failure.detail}", failure.detail!!.contains("header"))
    }

    @Test
    fun `rejects an empty file`() {
        val failure = readErrorOf(tempFolder.newFile("empty.db"))

        assertEquals(SyncFailureReason.INVALID_FILE, failure.reason)
    }

    // --- row validation, the F-02 cases -------------------------------------

    @Test
    fun `rejects a NULL name instead of throwing`() {
        val failure = readErrorOf(databaseWith { insertRow(id = 7, name = null) })

        assertEquals(SyncFailureReason.INVALID_FILE, failure.reason)
        assertTrue("detail should name the row: ${failure.detail}", failure.detail!!.contains("7"))
    }

    @Test
    fun `rejects a NULL cuisineType`() {
        assertEquals(
            SyncFailureReason.INVALID_FILE,
            readErrorOf(databaseWith { insertRow(cuisineType = null) }).reason
        )
    }

    @Test
    fun `rejects a blank name`() {
        assertEquals(
            SyncFailureReason.INVALID_FILE,
            readErrorOf(databaseWith { insertRow(name = "   ") }).reason
        )
    }

    // --- range validation, the F-01 cases -----------------------------------

    @Test
    fun `rejects a negative priceRange, which used to crash the screen`() {
        val failure = readErrorOf(databaseWith { insertRow(priceRange = -1) })

        assertEquals(SyncFailureReason.INVALID_FILE, failure.reason)
        assertTrue(failure.detail!!.contains("priceRange"))
    }

    @Test
    fun `rejects a priceRange above four`() {
        assertEquals(
            SyncFailureReason.INVALID_FILE,
            readErrorOf(databaseWith { insertRow(priceRange = 5) }).reason
        )
    }

    @Test
    fun `rejects a rating above five, which used to render seven of five stars`() {
        assertEquals(
            SyncFailureReason.INVALID_FILE,
            readErrorOf(databaseWith { insertRow(rating = 7) }).reason
        )
    }

    @Test
    fun `rejects a negative rating`() {
        assertEquals(
            SyncFailureReason.INVALID_FILE,
            readErrorOf(databaseWith { insertRow(rating = -1) }).reason
        )
    }

    @Test
    fun `accepts the range boundaries`() {
        val low = readRowsOf(databaseWith { insertRow(rating = 0, priceRange = 0) }).single()
        assertEquals(0, low.rating)
        assertEquals(0, low.priceRange)

        val high = readRowsOf(databaseWith { insertRow(rating = 5, priceRange = 4) }).single()
        assertEquals(5, high.rating)
        assertEquals(4, high.priceRange)
    }

    @Test
    fun `one bad row fails the whole import rather than importing a subset`() {
        val failure = readErrorOf(
            databaseWith {
                insertRow(id = 1, name = "Fine")
                insertRow(id = 2, rating = 99)
                insertRow(id = 3, name = "Also fine")
            }
        )
        assertEquals(SyncFailureReason.INVALID_FILE, failure.reason)
    }

    // --- empty data, the F-11 case ------------------------------------------

    @Test
    fun `accepts an empty table so you can sync back to zero restaurants`() {
        val outcome = RestaurantDatabaseReader.read(databaseWith())

        assertTrue("expected rows, got $outcome", outcome is ReadOutcome.Rows)
        assertTrue((outcome as ReadOutcome.Rows).restaurants.isEmpty())
    }

    private companion object {
        const val FULL_SCHEMA = """
            CREATE TABLE restaurants (
                id INTEGER PRIMARY KEY,
                name TEXT,
                cuisineType TEXT,
                address TEXT,
                rating INTEGER,
                priceRange INTEGER
            )
        """

        /** A file still carrying every column the reader has since stopped reading. */
        const val SCHEMA_WITH_DROPPED_COLUMNS = """
            CREATE TABLE restaurants (
                id INTEGER PRIMARY KEY,
                name TEXT,
                cuisineType TEXT,
                address TEXT,
                rating INTEGER,
                priceRange INTEGER,
                notes TEXT,
                visitDate INTEGER,
                photoUri TEXT,
                createdAt INTEGER
            )
        """

        const val SCHEMA_WITHOUT_CUISINE = """
            CREATE TABLE restaurants (
                id INTEGER PRIMARY KEY,
                name TEXT,
                address TEXT,
                rating INTEGER,
                priceRange INTEGER
            )
        """
    }
}
