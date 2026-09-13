package com.saatxi.eatapp.ui.edit

import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import com.saatxi.eatapp.data.local.Photo
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.mapslink.MapsLinkResolver
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
    fun `onPhotoPicked copies the pick right away and adds it to the carousel`() = runTest {
        val pickedUri = Uri.parse("content://media/picker/0/1")
        photoStorage.nextCopyResult = "/internal/photos/new.jpg"
        val viewModel = RestaurantEditViewModel(repository, photoStorage, MapsLinkResolver(), SavedStateHandle())
        observeState(viewModel)

        viewModel.onPhotoPicked(pickedUri)

        assertEquals(pickedUri, photoStorage.lastCopiedSource)
        assertEquals(listOf("/internal/photos/new.jpg"), viewModel.uiState.value.photoPaths)
    }

    @Test
    fun `saving with a freshly added photo persists its copied path`() = runTest {
        val pickedUri = Uri.parse("content://media/picker/0/1")
        val viewModel = RestaurantEditViewModel(repository, photoStorage, MapsLinkResolver(), SavedStateHandle())
        observeState(viewModel)
        viewModel.onNameChange("Cal Ferran")
        viewModel.onCuisineChange("mediterranean")
        photoStorage.nextCopyResult = "/internal/photos/new.jpg"
        viewModel.onPhotoPicked(pickedUri)

        viewModel.onSave(onSaved = {})

        assertEquals(pickedUri, photoStorage.lastCopiedSource)
        assertEquals(listOf("/internal/photos/new.jpg"), repository.lastAddedRestaurantPhotos?.second)
    }

    @Test
    fun `a copy that fails is silently dropped, leaving existing photos untouched`() = runTest {
        repository.restaurants.value = listOf(
            Restaurant(id = "1", name = "Cal Ferran", cuisineType = "mediterranean", streetAddress = null, priceRange = 1)
        )
        repository.photosByRestaurantId["1"] =
            listOf(Photo(id = "p1", restaurantId = "1", path = "/existing/photo.jpg", position = 0))
        val viewModel = RestaurantEditViewModel(repository, photoStorage, MapsLinkResolver(), SavedStateHandle(mapOf("restaurantId" to "1")))
        observeState(viewModel)
        photoStorage.nextCopyResult = null // simulates an unreadable/corrupt pick

        viewModel.onPhotoPicked(Uri.parse("content://media/picker/0/2"))

        assertEquals(listOf("/existing/photo.jpg"), viewModel.uiState.value.photoPaths)
    }
}
