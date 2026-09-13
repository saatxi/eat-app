package com.saatxi.eatapp.ui.roulette

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.prefs.FakeUserPreferencesRepository
import com.saatxi.eatapp.data.prefs.UserPreferences
import com.saatxi.eatapp.data.repository.FakeRestaurantRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import kotlin.random.Random

@OptIn(ExperimentalCoroutinesApi::class)
class RouletteViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var repository: FakeRestaurantRepository
    private lateinit var preferencesRepository: FakeUserPreferencesRepository

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        repository = FakeRestaurantRepository()
        preferencesRepository = FakeUserPreferencesRepository()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun TestScope.observeState(viewModel: RouletteViewModel) {
        backgroundScope.launch(dispatcher) { viewModel.uiState.collect {} }
    }

    private fun viewModel(random: Random = Random(0)) =
        RouletteViewModel(repository, preferencesRepository, random)

    @Test
    fun `starts with no pick and every candidate available`() = runTest {
        val viewModel = viewModel()
        observeState(viewModel)
        repository.restaurants.value = listOf(restaurant("1"), restaurant("2"))

        assertNull(viewModel.uiState.value.picked)
        assertEquals(2, viewModel.uiState.value.candidates.size)
    }

    @Test
    fun `pick always lands on a seeded index, deterministically`() = runTest {
        val viewModel = viewModel(random = Random(42))
        observeState(viewModel)
        repository.restaurants.value = listOf(restaurant("1"), restaurant("2"), restaurant("3"))

        viewModel.pick()
        val firstPick = viewModel.uiState.value.picked

        val replay = viewModel(random = Random(42))
        observeState(replay)
        repository.restaurants.value = listOf(restaurant("1"), restaurant("2"), restaurant("3"))
        replay.pick()

        assertEquals(firstPick, replay.uiState.value.picked)
    }

    @Test
    fun `pick increments pickCount even when landing on the same restaurant`() = runTest {
        val viewModel = viewModel()
        observeState(viewModel)
        repository.restaurants.value = listOf(restaurant("1"))

        viewModel.pick()
        assertEquals(1, viewModel.uiState.value.pickCount)
        viewModel.pick()
        assertEquals(2, viewModel.uiState.value.pickCount)
        assertEquals("1", viewModel.uiState.value.picked?.id)
    }

    @Test
    fun `pick against no candidates leaves picked null and reports empty`() = runTest {
        val viewModel = viewModel()
        observeState(viewModel)
        repository.restaurants.value = emptyList()

        viewModel.pick()

        assertNull(viewModel.uiState.value.picked)
        assertTrue(viewModel.uiState.value.isEmpty)
    }

    @Test
    fun `minRating narrows the candidates via the repository query`() = runTest {
        val viewModel = viewModel()
        observeState(viewModel)

        viewModel.onMinRatingChange(4)

        assertEquals(4, repository.lastMinRating)
    }

    @Test
    fun `visited narrows the candidates via the repository query`() = runTest {
        val viewModel = viewModel()
        observeState(viewModel)

        viewModel.onVisitedChange(false)

        assertEquals(false, repository.lastVisited)
        assertEquals(false, viewModel.uiState.value.visited)
    }

    @Test
    fun `visited only affects the repository query, not favoritesOnly or minRating`() = runTest {
        val viewModel = viewModel()
        observeState(viewModel)
        viewModel.onMinRatingChange(3)
        viewModel.onFavoritesOnlyChange(true)

        viewModel.onVisitedChange(true)

        assertEquals(3, viewModel.uiState.value.minRating)
        assertTrue(viewModel.uiState.value.favoritesOnly)
        assertEquals(true, viewModel.uiState.value.visited)
    }

    @Test
    fun `favoritesOnly narrows the candidates to favourited ids`() = runTest {
        val viewModel = viewModel()
        observeState(viewModel)
        repository.restaurants.value = listOf(restaurant("1"), restaurant("2"))
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf("1"))

        viewModel.onFavoritesOnlyChange(true)

        assertEquals(listOf("1"), viewModel.uiState.value.candidates.map { it.id })
    }

    @Test
    fun `a pick that falls out of the candidate pool after the filters change is cleared`() = runTest {
        val viewModel = viewModel()
        observeState(viewModel)
        repository.restaurants.value = listOf(restaurant("1"), restaurant("2"))
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = setOf("2"))
        viewModel.onFavoritesOnlyChange(true)
        viewModel.pick()
        assertEquals("2", viewModel.uiState.value.picked?.id)

        // Un-favourite the picked restaurant while still filtering to favourites only.
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(favoriteIds = emptySet())

        assertNull(viewModel.uiState.value.picked)
    }

    @Test
    fun `priceRange narrows the candidates to a matching price`() = runTest {
        val viewModel = viewModel()
        observeState(viewModel)
        repository.restaurants.value = listOf(restaurant("1", priceRange = 1), restaurant("2", priceRange = 3))

        viewModel.onPriceRangeChange(3)

        assertEquals(listOf("2"), viewModel.uiState.value.candidates.map { it.id })
        assertEquals(3, viewModel.uiState.value.priceRange)
    }

    private fun restaurant(id: String, priceRange: Int = 2) = Restaurant(
        id = id,
        name = "Restaurant $id",
        cuisineType = "mediterranean",
        streetAddress = null,
        priceRange = priceRange
    )
}
