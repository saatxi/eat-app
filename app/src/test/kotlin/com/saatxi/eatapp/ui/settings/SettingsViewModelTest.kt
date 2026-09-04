package com.saatxi.eatapp.ui.settings

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.prefs.AppLocaleManager
import com.saatxi.eatapp.data.prefs.UserPreferences
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.ui.theme.AppPalette
import com.saatxi.eatapp.ui.theme.ThemeMode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var preferencesRepository: FakeUserPreferencesRepository
    private lateinit var localeManager: FakeAppLocaleManager
    private lateinit var repository: FakeRestaurantRepository
    private lateinit var viewModel: SettingsViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        preferencesRepository = FakeUserPreferencesRepository()
        localeManager = FakeAppLocaleManager()
        repository = FakeRestaurantRepository()
        viewModel = SettingsViewModel(preferencesRepository, localeManager, repository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    /** uiState is a WhileSubscribed flow, so it only updates while collected. */
    private fun TestScope.observeState() {
        backgroundScope.launch(dispatcher) { viewModel.uiState.collect {} }
    }

    @Test
    fun `starts with the stored palette and theme mode`() = runTest {
        preferencesRepository.preferences.value = UserPreferences.Defaults.copy(
            palette = AppPalette.GARDEN,
            themeMode = ThemeMode.DARK
        )
        observeState()

        assertEquals(AppPalette.GARDEN, viewModel.uiState.value.palette)
        assertEquals(ThemeMode.DARK, viewModel.uiState.value.themeMode)
    }

    @Test
    fun `changing the palette writes through to the repository`() = runTest {
        observeState()

        viewModel.onPaletteChange(AppPalette.INDIGO)

        assertEquals(AppPalette.INDIGO, preferencesRepository.preferences.value.palette)
        assertEquals(AppPalette.INDIGO, viewModel.uiState.value.palette)
    }

    @Test
    fun `changing the theme mode writes through to the repository`() = runTest {
        observeState()

        viewModel.onThemeModeChange(ThemeMode.LIGHT)

        assertEquals(ThemeMode.LIGHT, preferencesRepository.preferences.value.themeMode)
        assertEquals(ThemeMode.LIGHT, viewModel.uiState.value.themeMode)
    }

    @Test
    fun `starts with the language reported by the locale manager`() = runTest {
        localeManager.current = AppLanguage.CATALAN
        viewModel = SettingsViewModel(preferencesRepository, localeManager, repository)
        observeState()

        assertEquals(AppLanguage.CATALAN, viewModel.uiState.value.language)
    }

    @Test
    fun `changing the language writes through to the locale manager`() = runTest {
        observeState()

        viewModel.onLanguageChange(AppLanguage.SPANISH)

        assertEquals(AppLanguage.SPANISH, localeManager.current)
        assertEquals(AppLanguage.SPANISH, viewModel.uiState.value.language)
    }

    @Test
    fun `deleting all data clears every restaurant`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = 1, name = "Cal Ferran", cuisineType = "mediterranean", address = null, rating = 4, priceRange = 2)
        )

        viewModel.onDeleteAllData()

        assertEquals(emptyList<Restaurant>(), repository.restaurants.value)
    }
}

/** Replays whatever the test pushes into [preferences] and records writes. */
private class FakeUserPreferencesRepository : UserPreferencesRepository {

    override val preferences = MutableStateFlow(UserPreferences.Defaults)

    override suspend fun setPalette(palette: AppPalette) {
        preferences.value = preferences.value.copy(palette = palette)
    }

    override suspend fun setThemeMode(themeMode: ThemeMode) {
        preferences.value = preferences.value.copy(themeMode = themeMode)
    }

    override suspend fun toggleFavorite(restaurantId: Long) {
        val current = preferences.value.favoriteIds
        preferences.value = preferences.value.copy(
            favoriteIds = if (restaurantId in current) current - restaurantId else current + restaurantId
        )
    }
}

/** Stands in for AppCompatDelegate, which is unavailable in a plain JUnit test. */
private class FakeAppLocaleManager(
    var current: AppLanguage = AppLanguage.Default
) : AppLocaleManager {
    override fun getLanguage(): AppLanguage = current
    override fun setLanguage(language: AppLanguage) {
        current = language
    }
}

/** Only exists to satisfy the constructor — onExportData needs a real Context to go further, so it is not exercised here. */
private class FakeRestaurantRepository : RestaurantRepository {

    val restaurants = MutableStateFlow<List<Restaurant>>(emptyList())

    override fun observeFiltered(
        query: String?,
        minRating: Int?,
        cuisineType: String?,
        sort: RestaurantSort,
        visited: Boolean?
    ): Flow<List<Restaurant>> = restaurants

    override fun observeCuisineTypes(): Flow<List<String>> = MutableStateFlow(emptyList())

    override fun observeById(id: Long): Flow<Restaurant?> =
        restaurants.map { list -> list.firstOrNull { it.id == id } }

    override suspend fun insert(restaurant: Restaurant): Long =
        throw NotImplementedError("Not used by SettingsViewModel")

    override suspend fun update(restaurant: Restaurant) =
        throw NotImplementedError("Not used by SettingsViewModel")

    override suspend fun delete(id: Long) =
        throw NotImplementedError("Not used by SettingsViewModel")

    override suspend fun deleteAll() {
        restaurants.value = emptyList()
    }
}
