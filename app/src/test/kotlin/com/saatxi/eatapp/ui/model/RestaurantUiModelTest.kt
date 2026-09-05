package com.saatxi.eatapp.ui.model

import com.saatxi.eatapp.data.local.Restaurant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The mapper is where every presentation decision that doesn't need a string
 * resource is made, so this is where those decisions are pinned down.
 */
class RestaurantUiModelTest {

    private fun entity(
        id: Long = 1,
        name: String = "Cal Ferran",
        cuisineType: String = "catalan",
        address: String? = "Carrer Gran 1",
        rating: Int = 3,
        priceRange: Int = 2,
        visited: Boolean = true,
        website: String? = null,
        instagram: String? = null,
        photoPath: String? = null
    ) = Restaurant(
        id = id,
        name = name,
        cuisineType = cuisineType,
        address = address,
        rating = rating,
        priceRange = priceRange,
        visited = visited,
        website = website,
        instagram = instagram,
        photoPath = photoPath
    )

    @Test
    fun `carries the identifying fields through unchanged`() {
        val model = entity(id = 7, name = "Bar Nil", cuisineType = "bar").toUiModel()

        assertEquals(7L, model.id)
        assertEquals("Bar Nil", model.name)
        assertEquals("bar", model.cuisineKey)
        assertEquals(3, model.rating)
    }

    @Test
    fun `the price range becomes one dollar sign per unit`() {
        assertEquals("", entity(priceRange = 0).toUiModel().priceLabel)
        assertEquals("$", entity(priceRange = 1).toUiModel().priceLabel)
        assertEquals("$$$$", entity(priceRange = 4).toUiModel().priceLabel)
    }

    /** Nothing valid can get here out of range, but the label stays sane if it does. */
    @Test
    fun `an out-of-range price range is clamped instead of drawn`() {
        assertEquals("$$$$", entity(priceRange = 99).toUiModel().priceLabel)
        assertEquals("", entity(priceRange = -1).toUiModel().priceLabel)
    }

    @Test
    fun `a missing or blank address is null, so the screens skip the row`() {
        assertNull(entity(address = null).toUiModel().address)
        assertNull(entity(address = "   ").toUiModel().address)
        assertEquals("Carrer Gran 1", entity().toUiModel().address)
    }

    @Test
    fun `links are carried through as stored, already validated on import`() {
        val model = entity(website = "https://example.com", instagram = "cal_ferran").toUiModel()

        assertEquals("https://example.com", model.website)
        assertEquals("cal_ferran", model.instagram)
    }

    /** Drives whether the detail screen draws a Links card at all. */
    @Test
    fun `hasLinks is true when either link is present and false when neither is`() {
        assertFalse(entity().toUiModel().hasLinks)
        assertTrue(entity(website = "https://example.com").toUiModel().hasLinks)
        assertTrue(entity(instagram = "cal_ferran").toUiModel().hasLinks)
    }

    /**
     * Favourites live outside the synced entity, so the mapper takes them as an
     * argument rather than reading them off the row.
     */
    @Test
    fun `favourite state comes from the caller, defaulting to not favourited`() {
        assertFalse(entity().toUiModel().isFavorite)
        assertTrue(entity().toUiModel(isFavorite = true).isFavorite)
    }

    @Test
    fun `visited is carried through unchanged, both ways`() {
        assertTrue(entity(visited = true).toUiModel().visited)
        assertFalse(entity(visited = false).toUiModel().visited)
    }

    /** Drives whether a row/card draws the stored photo instead of the cuisine badge. */
    @Test
    fun `photoPath is carried through unchanged, defaulting to null`() {
        assertNull(entity().toUiModel().photoPath)
        assertEquals("/data/user/0/com.saatxi.eatapp/files/photos/a.jpg", entity(photoPath = "/data/user/0/com.saatxi.eatapp/files/photos/a.jpg").toUiModel().photoPath)
    }
}
