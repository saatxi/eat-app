package com.saatxi.eatapp.ui.importing

import android.content.Context
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import com.saatxi.eatapp.data.local.CuisineCount
import com.saatxi.eatapp.data.local.PriceRangeCount
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.data.share.ImportFailureReason
import com.saatxi.eatapp.data.share.MAX_IMPORT_BYTES
import com.saatxi.eatapp.data.share.RestaurantExport
import com.saatxi.eatapp.data.share.RestaurantShareFile
import java.io.File
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Robolectric, not plain Kotlin: [RestaurantImportViewModel] reads a real
 * `Uri` through a real `Context`'s `ContentResolver` (see
 * `readContentUriCapped`), which needs a live Android runtime the same way
 * [com.saatxi.eatapp.data.local.RestaurantDaoTest] and
 * [com.saatxi.eatapp.data.photo.RestaurantPhotoStorageTest] do. `loadAndValidate()`
 * runs on a real `Dispatchers.IO`, not the test scheduler, so every test
 * awaits the result through the state flow (`first { !it.isLoading }`)
 * rather than reading `uiState.value` immediately after construction.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class RestaurantImportViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var context: Context
    private lateinit var repository: FakeRestaurantRepository

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        context = ApplicationProvider.getApplicationContext()
        repository = FakeRestaurantRepository()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        File(context.cacheDir, "import-test").deleteRecursively()
    }

    private fun export(name: String, address: String? = "Rambla 1") = RestaurantExport(
        name = name,
        cuisineType = "mediterranean",
        address = address,
        rating = 3,
        priceRange = 2
    )

    /** A real file under `cacheDir`, exposed through a `file://` Uri the same way a shared file's content Uri resolves. */
    private fun writeContentFile(name: String, text: String): Uri {
        val dir = File(context.cacheDir, "import-test").apply { mkdirs() }
        val file = File(dir, name).apply { writeText(text) }
        return Uri.fromFile(file)
    }

    private fun jsonOf(vararg restaurants: RestaurantExport) =
        Json.encodeToString(RestaurantShareFile.serializer(), RestaurantShareFile(restaurants = restaurants.toList()))

    private suspend fun RestaurantImportViewModel.loaded() = uiState.first { !it.isLoading }

    // --- loading and validating -------------------------------------------

    @Test
    fun `loads a valid file and defaults every candidate to add`() = runTest {
        val uri = writeContentFile("valid.json", jsonOf(export("Cal Ferran"), export("Bar Nil")))
        val viewModel = RestaurantImportViewModel(context, repository, uri)

        val state = viewModel.loaded()

        assertNull(state.error)
        assertEquals(listOf("Cal Ferran", "Bar Nil"), state.candidates.map { it.restaurant.name })
        assertTrue(state.candidates.all { it.decision == ImportDecision.ADD })
        assertTrue(state.candidates.all { it.duplicateOf == null })
    }

    @Test
    fun `reports how many rows the file itself dropped as invalid`() = runTest {
        val uri = writeContentFile("partly-invalid.json", jsonOf(export("Cal Ferran"), export(name = "  ")))
        val viewModel = RestaurantImportViewModel(context, repository, uri)

        val state = viewModel.loaded()

        assertEquals(1, state.skippedInvalidCount)
        assertEquals(listOf("Cal Ferran"), state.candidates.map { it.restaurant.name })
    }

    @Test
    fun `a candidate matching an existing restaurant by name and address defaults to skip`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = 5, name = "Cal Ferran", cuisineType = "mediterranean", address = "Rambla 1", rating = 4, priceRange = 2)
        )
        val uri = writeContentFile("duplicate.json", jsonOf(export("cal ferran", address = "rambla 1")))
        val viewModel = RestaurantImportViewModel(context, repository, uri)

        val candidate = viewModel.loaded().candidates.single()

        assertEquals(ImportDecision.SKIP, candidate.decision)
        assertEquals(5L, candidate.duplicateOf?.id)
    }

    @Test
    fun `a candidate with no matching existing restaurant defaults to add`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = 5, name = "Cal Ferran", cuisineType = "mediterranean", address = "Rambla 1", rating = 4, priceRange = 2)
        )
        val uri = writeContentFile("no-duplicate.json", jsonOf(export("Bar Nil", address = "Carrer Nou 4")))
        val viewModel = RestaurantImportViewModel(context, repository, uri)

        val candidate = viewModel.loaded().candidates.single()

        assertEquals(ImportDecision.ADD, candidate.decision)
        assertNull(candidate.duplicateOf)
    }

    @Test
    fun `a file over the size cap is rejected as too large`() = runTest {
        val uri = writeContentFile("huge.json", "x".repeat(MAX_IMPORT_BYTES.toInt() + 1))
        val viewModel = RestaurantImportViewModel(context, repository, uri)

        val state = viewModel.loaded()

        assertEquals(ImportFailureReason.TOO_LARGE, state.error)
        assertTrue(state.candidates.isEmpty())
    }

    @Test
    fun `a uri nothing can be read from is reported as an io error`() = runTest {
        val missing = Uri.fromFile(File(context.cacheDir, "import-test/does-not-exist.json"))
        val viewModel = RestaurantImportViewModel(context, repository, missing)

        val state = viewModel.loaded()

        assertEquals(ImportFailureReason.IO_ERROR, state.error)
    }

    @Test
    fun `malformed content is reported as an invalid file`() = runTest {
        val uri = writeContentFile("garbage.json", "not json at all")
        val viewModel = RestaurantImportViewModel(context, repository, uri)

        val state = viewModel.loaded()

        assertEquals(ImportFailureReason.INVALID_FILE, state.error)
    }

    // --- reviewing and confirming -------------------------------------------

    @Test
    fun `onDecisionChange updates only the targeted candidate`() = runTest {
        val uri = writeContentFile("two.json", jsonOf(export("Cal Ferran"), export("Bar Nil")))
        val viewModel = RestaurantImportViewModel(context, repository, uri)
        viewModel.loaded()

        viewModel.onDecisionChange(1, ImportDecision.SKIP)

        val candidates = viewModel.uiState.value.candidates
        assertEquals(ImportDecision.ADD, candidates[0].decision)
        assertEquals(ImportDecision.SKIP, candidates[1].decision)
    }

    @Test
    fun `confirming inserts every add decision`() = runTest {
        val uri = writeContentFile("add.json", jsonOf(export("Cal Ferran")))
        val viewModel = RestaurantImportViewModel(context, repository, uri)
        viewModel.loaded()
        var done = false

        viewModel.onConfirm(onDone = { done = true })

        assertTrue(done)
        assertEquals(listOf("Cal Ferran"), repository.inserted.map { it.name })
    }

    @Test
    fun `confirming a skip decision inserts and updates nothing`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = 5, name = "Cal Ferran", cuisineType = "mediterranean", address = "Rambla 1", rating = 4, priceRange = 2)
        )
        val uri = writeContentFile("skip.json", jsonOf(export("Cal Ferran")))
        val viewModel = RestaurantImportViewModel(context, repository, uri)
        viewModel.loaded()

        viewModel.onConfirm(onDone = {})

        assertTrue(repository.inserted.isEmpty())
        assertTrue(repository.updated.isEmpty())
    }

    @Test
    fun `confirming a replace decision updates the existing row's id`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = 5, name = "Cal Ferran", cuisineType = "mediterranean", address = "Rambla 1", rating = 2, priceRange = 1)
        )
        val uri = writeContentFile("replace.json", jsonOf(export("Cal Ferran", address = "Rambla 1").copy(rating = 5)))
        val viewModel = RestaurantImportViewModel(context, repository, uri)
        viewModel.loaded()
        viewModel.onDecisionChange(0, ImportDecision.REPLACE)

        viewModel.onConfirm(onDone = {})

        val updated = repository.updated.single()
        assertEquals(5L, updated.id)
        assertEquals(5, updated.rating)
    }
}

internal class FakeRestaurantRepository : RestaurantRepository {

    val restaurants = MutableStateFlow<List<Restaurant>>(emptyList())
    val inserted = mutableListOf<Restaurant>()
    val updated = mutableListOf<Restaurant>()

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort,
        visited: Boolean?
    ): Flow<List<Restaurant>> = restaurants

    override fun observeCuisineTypes(): Flow<List<String>> =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override fun observeById(id: Long): Flow<Restaurant?> =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override suspend fun insert(restaurant: Restaurant, tags: List<String>): Long {
        inserted += restaurant
        return restaurant.id
    }

    override suspend fun update(restaurant: Restaurant, tags: List<String>) {
        updated += restaurant
    }

    override suspend fun delete(id: Long) =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override suspend fun deleteAll() =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override fun observeAllTagNames(): Flow<List<String>> =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override fun observeTagNames(restaurantId: Long): Flow<List<String>> =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override fun observeTagsByRestaurantId(): Flow<Map<Long, List<String>>> =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override fun observeTotalCount(): Flow<Int> =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override fun observeVisitedCount(): Flow<Int> =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override fun observeAverageRating(): Flow<Double?> =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override fun observeCuisineCounts(): Flow<List<CuisineCount>> =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override fun observePriceRangeCounts(): Flow<List<PriceRangeCount>> =
        throw NotImplementedError("Not used by RestaurantImportViewModel")

    override suspend fun getRandomWantToTry(): Restaurant? =
        throw NotImplementedError("Not used by RestaurantImportViewModel")
}
