package com.albertferran.eatapp.data.local

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.albertferran.eatapp.data.repository.RoomRestaurantRepository
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The filter query, exercised through [RoomRestaurantRepository] so the query
 * folding that makes F-14 work is covered along with the SQL itself.
 */
@RunWith(RobolectricTestRunner::class)
class RestaurantDaoTest {

    private lateinit var database: EatAppDatabase
    private lateinit var dao: RestaurantDao
    private lateinit var repository: RoomRestaurantRepository

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            EatAppDatabase::class.java
        ).allowMainThreadQueries().build()
        dao = database.restaurantDao()
        repository = RoomRestaurantRepository(dao)
    }

    @After
    fun tearDown() {
        database.close()
    }

    private fun restaurant(
        id: Long,
        name: String,
        cuisineType: String = "mediterranean",
        address: String? = "Rambla 1",
        rating: Int = 3,
        priceRange: Int = 2
    ) = Restaurant(
        id = id,
        name = name,
        cuisineType = cuisineType,
        address = address,
        rating = rating,
        priceRange = priceRange
    )

    private suspend fun seed(vararg restaurants: Restaurant) = dao.replaceAll(restaurants.toList())

    private suspend fun search(query: String?) =
        repository.observeFiltered(query, null, null).first().map { it.name }

    // --- ordering and the unfiltered case -----------------------------------

    @Test
    fun `returns everything when no filter is set`() = runTest {
        seed(restaurant(1, "Bar Nil"), restaurant(2, "Alga"))

        assertEquals(listOf("Alga", "Bar Nil"), search(null))
    }

    @Test
    fun `sorts by name, ignoring case`() = runTest {
        seed(restaurant(1, "zeta"), restaurant(2, "Alfa"), restaurant(3, "beta"))

        assertEquals(listOf("Alfa", "beta", "zeta"), search(null))
    }

    @Test
    fun `treats a blank query as no filter at all`() = runTest {
        seed(restaurant(1, "Alga"))

        assertEquals(listOf("Alga"), search("   "))
    }

    // --- what the search covers, which is F-13 ------------------------------

    @Test
    fun `matches on name`() = runTest {
        seed(restaurant(1, "Cal Ferran"), restaurant(2, "Bar Nil"))

        assertEquals(listOf("Cal Ferran"), search("ferran"))
    }

    @Test
    fun `matches on cuisine key`() = runTest {
        seed(
            restaurant(1, "Sakura", cuisineType = "japanese"),
            restaurant(2, "Alga", cuisineType = "seafood")
        )

        assertEquals(listOf("Sakura"), search("japanese"))
    }

    @Test
    fun `matches on address`() = runTest {
        seed(
            restaurant(1, "Cal Ferran", address = "Carrer Nou 4"),
            restaurant(2, "Bar Nil", address = "Rambla 12")
        )

        assertEquals(listOf("Cal Ferran"), search("carrer nou"))
    }

    @Test
    fun `returns nothing when the query matches nothing`() = runTest {
        seed(restaurant(1, "Cal Ferran"))

        assertEquals(emptyList<String>(), search("sushi"))
    }

    // --- accent handling, which is F-14 -------------------------------------

    @Test
    fun `an unaccented query finds accented data`() = runTest {
        // Both rows use a cuisine key that does not itself contain the term.
        seed(
            restaurant(1, "Mediterrànea", cuisineType = "italian"),
            restaurant(2, "Bar Nil", cuisineType = "italian")
        )

        assertEquals(listOf("Mediterrànea"), search("Mediterranea"))
    }

    @Test
    fun `an accented query finds unaccented data`() = runTest {
        seed(
            restaurant(1, "Mediterranea", cuisineType = "italian"),
            restaurant(2, "Bar Nil", cuisineType = "italian")
        )

        assertEquals(listOf("Mediterranea"), search("Mediterránea"))
    }

    @Test
    fun `accents in the address are folded too`() = runTest {
        seed(restaurant(1, "Cal Ferran", address = "Plaça Santa Anna, Mataró"))

        assertEquals(listOf("Cal Ferran"), search("placa"))
        assertEquals(listOf("Cal Ferran"), search("mataro"))
        assertEquals(listOf("Cal Ferran"), search("MATARÓ"))
    }

    @Test
    fun `matching is case-insensitive`() = runTest {
        seed(restaurant(1, "Cal Ferran"))

        assertEquals(listOf("Cal Ferran"), search("CAL FERRAN"))
    }

    // --- the other filters --------------------------------------------------

    @Test
    fun `filters by minimum rating inclusively`() = runTest {
        seed(
            restaurant(1, "One", rating = 1),
            restaurant(2, "Three", rating = 3),
            restaurant(3, "Five", rating = 5)
        )

        val names = repository.observeFiltered(null, 3, null).first().map { it.name }
        assertEquals(listOf("Five", "Three"), names)
    }

    @Test
    fun `filters by cuisine on an exact key match`() = runTest {
        seed(
            restaurant(1, "Sakura", cuisineType = "japanese"),
            restaurant(2, "Alga", cuisineType = "seafood")
        )

        val names = repository.observeFiltered(null, null, "japanese").first().map { it.name }
        assertEquals(listOf("Sakura"), names)
    }

    @Test
    fun `combines all three filters`() = runTest {
        seed(
            restaurant(1, "Sakura", cuisineType = "japanese", rating = 5, address = "Carrer Sushi 1"),
            restaurant(2, "Kioto", cuisineType = "japanese", rating = 2, address = "Carrer Sushi 2"),
            restaurant(3, "Alga", cuisineType = "seafood", rating = 5, address = "Carrer Sushi 3")
        )

        val names = repository.observeFiltered("sushi", 4, "japanese").first().map { it.name }
        assertEquals(listOf("Sakura"), names)
    }

    @Test
    fun `a blank cuisine is ignored rather than matching nothing`() = runTest {
        seed(restaurant(1, "Sakura", cuisineType = "japanese"))

        val names = repository.observeFiltered(null, null, "  ").first().map { it.name }
        assertEquals(listOf("Sakura"), names)
    }

    // --- the other queries --------------------------------------------------

    @Test
    fun `lists each cuisine present in the data once`() = runTest {
        seed(
            restaurant(1, "Sakura", cuisineType = "japanese"),
            restaurant(2, "Kioto", cuisineType = "japanese"),
            restaurant(3, "Alga", cuisineType = "seafood")
        )

        assertEquals(setOf("japanese", "seafood"), repository.observeCuisineTypes().first().toSet())
    }

    @Test
    fun `observeById returns the row`() = runTest {
        seed(restaurant(1, "Cal Ferran"))

        assertEquals("Cal Ferran", repository.observeById(1).first()?.name)
    }

    @Test
    fun `observeById emits null for a row that is not there`() = runTest {
        seed(restaurant(1, "Cal Ferran"))

        assertNull(repository.observeById(99).first())
    }

    @Test
    fun `replaceAll wipes the previous contents rather than merging`() = runTest {
        seed(restaurant(1, "Old One"), restaurant(2, "Old Two"))
        seed(restaurant(3, "New One"))

        assertEquals(listOf("New One"), search(null))
    }

    @Test
    fun `replaceAll accepts an empty list`() = runTest {
        seed(restaurant(1, "Cal Ferran"))
        dao.replaceAll(emptyList())

        assertEquals(emptyList<String>(), search(null))
    }

    // --- LIKE metacharacters, which is F-15 ---------------------------------

    @Test
    fun `a percent sign in the query is matched literally, not as a wildcard`() = runTest {
        seed(restaurant(1, "Cal Ferran"), restaurant(2, "Bar Nil"))

        assertEquals(emptyList<String>(), search("%"))
    }

    @Test
    fun `an underscore in the query is matched literally, not as a wildcard`() = runTest {
        seed(restaurant(1, "Cal Ferran"))

        assertEquals(emptyList<String>(), search("_al"))
    }

    @Test
    fun `a literal percent sign in the data still matches`() = runTest {
        seed(restaurant(1, "100% Fresh"), restaurant(2, "Bar Nil"))

        assertEquals(listOf("100% Fresh"), search("100%"))
    }

    @Test
    fun `a literal underscore in the data still matches`() = runTest {
        seed(restaurant(1, "Cal_Ferran"), restaurant(2, "Bar Nil"))

        assertEquals(listOf("Cal_Ferran"), search("cal_ferran"))
    }

    @Test
    fun `a backslash in the query is matched literally`() = runTest {
        seed(restaurant(1, "Cal\\Ferran"), restaurant(2, "Bar Nil"))

        assertEquals(listOf("Cal\\Ferran"), search("cal\\ferran"))
    }
}
