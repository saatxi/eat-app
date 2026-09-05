package com.saatxi.eatapp.ui.edit

import android.net.Uri
import com.saatxi.eatapp.data.local.Restaurant
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
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The `RestaurantEditViewModelTest` cases that need an actual [Uri] — a
 * pending photo pick — split out into their own Robolectric-backed class:
 * `android.net.Uri` isn't usable from a plain JVM unit test (its methods are
 * stubbed to throw, the same reason the rest of the suite avoids touching
 * real Android types), and Robolectric is what this codebase already reaches
 * for when that's unavoidable — see `RestaurantDaoTest`. Everything else
 * about [RestaurantEditViewModel] stays covered by the faster, Robolectric-free
 * [RestaurantEditViewModelTest].
 */
@RunWith(RobolectricTestRunner::class)
@OptIn(ExperimentalCoroutinesApi::class)
class RestaurantEditViewModelPhotoTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var repository: FakeRestaurantRepository
    private lateinit var photoStorage: FakeRestaurantPhotoStorage

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        repository = FakeRestaurantRepository()
        photoStorage = FakeRestaurantPhotoStorage()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun TestScope.observeState(viewModel: RestaurantEditViewModel) {
        backgroundScope.launch(dispatcher) { viewModel.uiState.collect {} }
    }

    @Test
    fun `onPhotoPicked previews the pick immediately, before it is ever copied`() = runTest {
        val pickedUri = Uri.parse("content://media/picker/0/1")
        val viewModel = RestaurantEditViewModel(repository, photoStorage, restaurantId = null)
        observeState(viewModel)

        viewModel.onPhotoPicked(pickedUri)

        assertEquals(pickedUri, viewModel.uiState.value.previewPhoto)
        assertNull(photoStorage.lastCopiedSource)
    }

    @Test
    fun `saving with a pending pick copies it and stores the resulting path`() = runTest {
        val pickedUri = Uri.parse("content://media/picker/0/1")
        val viewModel = RestaurantEditViewModel(repository, photoStorage, restaurantId = null)
        observeState(viewModel)
        viewModel.onNameChange("Cal Ferran")
        viewModel.onCuisineChange("mediterranean")
        viewModel.onPhotoPicked(pickedUri)
        photoStorage.nextCopyResult = "/internal/photos/new.jpg"

        viewModel.onSave(onSaved = {})

        assertEquals(pickedUri, photoStorage.lastCopiedSource)
        assertEquals("/internal/photos/new.jpg", repository.lastInserted?.photoPath)
    }

    @Test
    fun `a copy that fails falls back to the photo that was already there`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = 1, name = "Cal Ferran", cuisineType = "mediterranean", address = null, rating = 3, priceRange = 1, photoPath = "/existing/photo.jpg")
        )
        val viewModel = RestaurantEditViewModel(repository, photoStorage, restaurantId = 1L)
        observeState(viewModel)
        viewModel.onPhotoPicked(Uri.parse("content://media/picker/0/2"))
        photoStorage.nextCopyResult = null // simulates an unreadable/corrupt pick

        viewModel.onSave(onSaved = {})

        assertEquals("/existing/photo.jpg", repository.lastUpdated?.photoPath)
    }
}
