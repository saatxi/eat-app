package com.saatxi.eatapp.data.local

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.saatxi.eatapp.data.repository.RoomRestaurantRepository
import com.saatxi.eatapp.data.share.RestaurantShareFile
import java.io.File
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
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

    private lateinit var context: Context
    private lateinit var database: EatAppDatabase
    private lateinit var dao: RestaurantDao
    private lateinit var repository: RoomRestaurantRepository

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        database = Room.inMemoryDatabaseBuilder(context, EatAppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        dao = database.restaurantDao()
        repository = RoomRestaurantRepository(dao, context)
    }

    @After
    fun tearDown() {
        database.close()
        File(context.filesDir, "backup.json").delete()
        File(context.filesDir, "photos").deleteRecursively()
    }

    private fun restaurant(
        id: Long,
        name: String,
        cuisineType: String = "mediterranean",
        address: String? = "Rambla 1",
        rating: Int = 3,
        priceRange: Int = 2,
        visited: Boolean = true
    ) = Restaurant(
        id = id,
        name = name,
        cuisineType = cuisineType,
        address = address,
        rating = rating,
        priceRange = priceRange,
        visited = visited
    )

    private suspend fun seed(vararg restaurants: Restaurant) {
        restaurants.forEach { dao.insert(it) }
    }

    private suspend fun search(query: String?) =
        repository.observeFiltered(query, null, null).first().map { it.name }

    private suspend fun sortedBy(sort: RestaurantSort) =
        repository.observeFiltered(null, null, null, sort).first().map { it.name }

    private suspend fun filteredByVisited(visited: Boolean?) =
        repository.observeFiltered(null, null, null, RestaurantSort.NAME, visited).first().map { it.name }

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
    fun `sorts by rating, highest first, when asked to`() = runTest {
        seed(
            restaurant(1, "Alga", rating = 2),
            restaurant(2, "Bar Nil", rating = 5),
            restaurant(3, "Can Pep", rating = 3)
        )

        assertEquals(listOf("Bar Nil", "Can Pep", "Alga"), sortedBy(RestaurantSort.RATING))
    }

    /** Ties would otherwise come back in whatever order SQLite happened to pick. */
    @Test
    fun `breaks equal ratings with the name order`() = runTest {
        seed(
            restaurant(1, "zeta", rating = 4),
            restaurant(2, "Alfa", rating = 4),
            restaurant(3, "beta", rating = 5)
        )

        assertEquals(listOf("beta", "Alfa", "zeta"), sortedBy(RestaurantSort.RATING))
    }

    @Test
    fun `the name order is unaffected by how the ratings fall`() = runTest {
        seed(
            restaurant(1, "zeta", rating = 5),
            restaurant(2, "Alfa", rating = 1)
        )

        assertEquals(listOf("Alfa", "zeta"), sortedBy(RestaurantSort.NAME))
    }

    @Test
    fun `sorting by rating still respects the filters`() = runTest {
        seed(
            restaurant(1, "Alga", rating = 5, cuisineType = "japanese"),
            restaurant(2, "Bar Nil", rating = 4, cuisineType = "seafood"),
            restaurant(3, "Can Pep", rating = 3, cuisineType = "seafood")
        )

        val names = repository
            .observeFiltered(null, null, "seafood", RestaurantSort.RATING)
            .first()
            .map { it.name }

        assertEquals(listOf("Bar Nil", "Can Pep"), names)
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

    @Test
    fun `no visited filter returns both visited and want-to-try rows`() = runTest {
        seed(restaurant(1, "Been There", visited = true), restaurant(2, "Want To Go", visited = false))

        assertEquals(listOf("Been There", "Want To Go"), filteredByVisited(null))
    }

    @Test
    fun `filtering by visited true returns only visited rows`() = runTest {
        seed(restaurant(1, "Been There", visited = true), restaurant(2, "Want To Go", visited = false))

        assertEquals(listOf("Been There"), filteredByVisited(true))
    }

    @Test
    fun `filtering by visited false returns only want-to-try rows`() = runTest {
        seed(restaurant(1, "Been There", visited = true), restaurant(2, "Want To Go", visited = false))

        assertEquals(listOf("Want To Go"), filteredByVisited(false))
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

    // --- writes: insert, update, delete --------------------------------------

    @Test
    fun `insert assigns a fresh id when given zero`() = runTest {
        val id = dao.insert(restaurant(0, "Cal Ferran"))

        assertEquals(listOf("Cal Ferran"), search(null))
        assertEquals("Cal Ferran", repository.observeById(id).first()?.name)
    }

    @Test
    fun `update changes an existing row in place`() = runTest {
        val id = dao.insert(restaurant(0, "Old Name", rating = 2))

        dao.update(restaurant(id, "New Name", rating = 5))

        val updated = repository.observeById(id).first()
        assertEquals("New Name", updated?.name)
        assertEquals(5, updated?.rating)
    }

    @Test
    fun `notes persist through insert and read back unchanged`() = runTest {
        val id = dao.insert(restaurant(0, "Cal Ferran").copy(notes = "Ask for the burrata"))

        assertEquals("Ask for the burrata", repository.observeById(id).first()?.notes)
    }

    @Test
    fun `delete removes only the matching row`() = runTest {
        seed(restaurant(1, "Keep"), restaurant(2, "Remove"))

        dao.delete(2)

        assertEquals(listOf("Keep"), search(null))
    }

    @Test
    fun `deleteAll removes every row`() = runTest {
        seed(restaurant(1, "One"), restaurant(2, "Two"))

        dao.deleteAll()

        assertEquals(emptyList<String>(), search(null))
    }

    // --- photo file cleanup (F-63), through the repository -------------------

    /** A real file under `filesDir/photos/`, the same place `RestaurantPhotoStorage` writes to. */
    private fun fakePhotoFile(name: String): File {
        val dir = File(context.filesDir, "photos").apply { mkdirs() }
        return File(dir, name).apply { writeText("fake image bytes") }
    }

    @Test
    fun `update deletes the old photo file once it is replaced by a new one`() = runTest {
        val oldPhoto = fakePhotoFile("old.jpg")
        val id = repository.insert(restaurant(0, "Cal Ferran").copy(photoPath = oldPhoto.absolutePath))

        repository.update(restaurant(id, "Cal Ferran").copy(photoPath = "/photos/new.jpg"))

        assertFalse(oldPhoto.exists())
    }

    @Test
    fun `update leaves the photo file alone when the path does not change`() = runTest {
        val photo = fakePhotoFile("unchanged.jpg")
        val id = repository.insert(restaurant(0, "Cal Ferran").copy(photoPath = photo.absolutePath))

        repository.update(restaurant(id, "New Name").copy(photoPath = photo.absolutePath))

        assertTrue(photo.exists())
    }

    @Test
    fun `delete removes the row's photo file`() = runTest {
        val photo = fakePhotoFile("to-delete.jpg")
        val id = repository.insert(restaurant(0, "Cal Ferran").copy(photoPath = photo.absolutePath))

        repository.delete(id)

        assertFalse(photo.exists())
    }

    @Test
    fun `deleteAll wipes every photo file at once`() = runTest {
        val first = fakePhotoFile("one.jpg")
        val second = fakePhotoFile("two.jpg")
        repository.insert(restaurant(0, "One").copy(photoPath = first.absolutePath))
        repository.insert(restaurant(0, "Two").copy(photoPath = second.absolutePath))

        repository.deleteAll()

        assertFalse(first.exists())
        assertFalse(second.exists())
    }

    // --- statistics (F-64), through the repository ----------------------------

    @Test
    fun `total and visited counts reflect what was inserted`() = runTest {
        seed(restaurant(1, "Been There", visited = true), restaurant(2, "Want To Go", visited = false))

        assertEquals(2, repository.observeTotalCount().first())
        assertEquals(1, repository.observeVisitedCount().first())
    }

    @Test
    fun `average rating ignores unrated rows`() = runTest {
        // A want-to-try row saved with no rating yet (rating = 0) must not drag the
        // average down as if it were a real, badly-rated visit.
        seed(
            restaurant(1, "Four Stars", rating = 4),
            restaurant(2, "Two Stars", rating = 2),
            restaurant(3, "Not Rated Yet", rating = 0, visited = false)
        )

        assertEquals(3.0, repository.observeAverageRating().first())
    }

    @Test
    fun `average rating is null when nothing has a real rating`() = runTest {
        seed(restaurant(1, "Not Rated Yet", rating = 0, visited = false))

        assertNull(repository.observeAverageRating().first())
    }

    @Test
    fun `cuisine counts group by cuisine, highest first`() = runTest {
        seed(
            restaurant(1, "Sakura", cuisineType = "japanese"),
            restaurant(2, "Kioto", cuisineType = "japanese"),
            restaurant(3, "Alga", cuisineType = "seafood")
        )

        assertEquals(
            listOf(CuisineCount("japanese", 2), CuisineCount("seafood", 1)),
            repository.observeCuisineCounts().first()
        )
    }

    @Test
    fun `price range counts group by price range`() = runTest {
        seed(
            restaurant(1, "One", priceRange = 1),
            restaurant(2, "Two", priceRange = 2),
            restaurant(3, "Also Two", priceRange = 2)
        )

        val counts = repository.observePriceRangeCounts().first().associate { it.priceRange to it.count }
        assertEquals(mapOf(1 to 1, 2 to 2), counts)
    }

    // --- Part 3: backup.json, written through the repository -----------------

    private fun backupFile() = File(context.filesDir, "backup.json")

    private fun backupNames(): List<String> {
        val shareFile = Json.decodeFromString(RestaurantShareFile.serializer(), backupFile().readText())
        return shareFile.restaurants.map { it.name }
    }

    @Test
    fun `no backup file exists before any write`() {
        assertFalse(backupFile().exists())
    }

    @Test
    fun `insert writes a backup file with the new row`() = runTest {
        repository.insert(restaurant(0, "Cal Ferran"))

        assertEquals(listOf("Cal Ferran"), backupNames())
    }

    @Test
    fun `update rewrites the backup file with the change`() = runTest {
        val id = repository.insert(restaurant(0, "Old Name"))

        repository.update(restaurant(id, "New Name"))

        assertEquals(listOf("New Name"), backupNames())
    }

    @Test
    fun `delete rewrites the backup file without the removed row`() = runTest {
        repository.insert(restaurant(0, "Keep"))
        val removeId = repository.insert(restaurant(0, "Remove"))

        repository.delete(removeId)

        assertEquals(listOf("Keep"), backupNames())
    }

    @Test
    fun `deleteAll rewrites the backup file as empty`() = runTest {
        repository.insert(restaurant(0, "Keep"))
        repository.insert(restaurant(0, "Remove"))

        repository.deleteAll()

        assertEquals(emptyList<String>(), backupNames())
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
