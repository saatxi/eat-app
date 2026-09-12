package com.saatxi.eatapp.ui.logvisit

import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import com.saatxi.eatapp.data.photo.RestaurantPhotoStorage
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
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Robolectric-backed (like `RestaurantEditViewModelPhotoTest`) because photo
 * picking needs a real `android.net.Uri`, which throws on a plain JVM test.
 */
@RunWith(RobolectricTestRunner::class)
@OptIn(ExperimentalCoroutinesApi::class)
class LogVisitViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var repository: FakeRestaurantRepository
    private lateinit var photoStorage: FakePhotoStorage
    private lateinit var viewModel: LogVisitViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        repository = FakeRestaurantRepository()
        photoStorage = FakePhotoStorage()
        viewModel = LogVisitViewModel(repository, photoStorage, SavedStateHandle(mapOf("restaurantId" to "1")))
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun TestScope.observeState() {
        backgroundScope.launch(dispatcher) { viewModel.uiState.collect {} }
    }

    @Test
    fun `starts with today's date, no rating and no photos`() = runTest {
        observeState()

        val state = viewModel.uiState.value
        assertEquals(0, state.rating)
        assertEquals("", state.notes)
        assertTrue(state.photoPaths.isEmpty())
        assertFalse(state.isSaving)
    }

    @Test
    fun `onRatingChange clamps to the 0 to 5 range`() = runTest {
        observeState()

        viewModel.onRatingChange(9)
        assertEquals(5, viewModel.uiState.value.rating)

        viewModel.onRatingChange(-3)
        assertEquals(0, viewModel.uiState.value.rating)
    }

    @Test
    fun `onDateChange updates the visit date`() = runTest {
        observeState()

        viewModel.onDateChange(12345L)

        assertEquals(12345L, viewModel.uiState.value.visitDate)
    }

    @Test
    fun `onPhotoPicked copies the photo and appends its path`() = runTest {
        observeState()
        photoStorage.nextCopyResult = "/fake/photos/1.jpg"

        viewModel.onPhotoPicked(Uri.parse("content://media/picker/0/1"))

        assertEquals(listOf("/fake/photos/1.jpg"), viewModel.uiState.value.photoPaths)
    }

    @Test
    fun `a photo pick that fails to copy is silently dropped`() = runTest {
        observeState()
        photoStorage.nextCopyResult = null

        viewModel.onPhotoPicked(Uri.parse("content://media/picker/0/1"))

        assertTrue(viewModel.uiState.value.photoPaths.isEmpty())
    }

    @Test
    fun `onRemovePhoto removes just the matching path`() = runTest {
        observeState()
        photoStorage.nextCopyResult = "/fake/photos/1.jpg"
        viewModel.onPhotoPicked(Uri.parse("content://media/picker/0/1"))
        photoStorage.nextCopyResult = "/fake/photos/2.jpg"
        viewModel.onPhotoPicked(Uri.parse("content://media/picker/0/2"))

        viewModel.onRemovePhoto("/fake/photos/1.jpg")

        assertEquals(listOf("/fake/photos/2.jpg"), viewModel.uiState.value.photoPaths)
    }

    @Test
    fun `onSave adds a visit with the current form fields and calls back`() = runTest {
        observeState()
        viewModel.onDateChange(500L)
        viewModel.onRatingChange(4)
        viewModel.onNotesChange("  Great burrata  ")
        photoStorage.nextCopyResult = "/fake/photos/1.jpg"
        viewModel.onPhotoPicked(Uri.parse("content://media/picker/0/1"))
        var done = false

        viewModel.onSave(onSaved = { done = true })

        assertTrue(done)
        val visit = repository.lastAddedVisit
        assertEquals("1", visit?.restaurantId)
        assertEquals(500L, visit?.visitDate)
        assertEquals(4, visit?.rating)
        assertEquals("Great burrata", visit?.notes)
        assertEquals(listOf("/fake/photos/1.jpg"), repository.lastAddedVisitPhotoPaths)
    }

    @Test
    fun `onSave treats a blank note as none`() = runTest {
        observeState()

        viewModel.onSave(onSaved = {})

        assertEquals(null, repository.lastAddedVisit?.notes)
    }
}

private class FakePhotoStorage : RestaurantPhotoStorage {
    var nextCopyResult: String? = "/fake/photos/default.jpg"
    override suspend fun copy(source: Uri): String? = nextCopyResult
}
