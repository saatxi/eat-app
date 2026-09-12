package com.saatxi.eatapp.ui.model

import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.Visit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The mapper is where every presentation decision that doesn't need a string
 * resource is made, so this is where those decisions are pinned down.
 * Rating/visited/notes now come from the restaurant's latest [Visit], passed
 * in separately — see [toUiModel].
 */
class RestaurantUiModelTest {

    private fun entity(
        id: String = "1",
        name: String = "Cal Ferran",
        cuisineType: String = "catalan",
        address: String? = "Carrer Gran 1",
        city: String? = null,
        region: String? = null,
        country: String? = null,
        priceRange: Int = 2,
        website: String? = null,
        instagram: String? = null
    ) = Restaurant(
        id = id,
        name = name,
        cuisineType = cuisineType,
        streetAddress = address,
        city = city,
        region = region,
        country = country,
        priceRange = priceRange,
        website = website,
        instagram = instagram
    )

    private fun visit(rating: Int = 3, notes: String? = null) = Visit(id = "v", restaurantId = "1", visitDate = 0L, rating = rating, notes = notes)

    @Test
    fun `carries the identifying fields through unchanged`() {
        val model = entity(id = "7", name = "Bar Nil", cuisineType = "bar").toUiModel(latestVisit = visit(rating = 3))

        assertEquals("7", model.id)
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
    fun `a missing or blank street address is null, so the screens skip the row`() {
        assertNull(entity(address = null).toUiModel().streetAddress)
        assertNull(entity(address = "   ").toUiModel().streetAddress)
        assertEquals("Carrer Gran 1", entity().toUiModel().streetAddress)
    }

    @Test
    fun `formattedAddress is null when every component is missing`() {
        assertNull(entity(address = null).toUiModel().formattedAddress)
    }

    @Test
    fun `formattedAddress joins the present components with commas`() {
        val model = entity(address = "Carrer Gran 1", city = "Girona", region = "Girona (província)", country = "Spain").toUiModel()

        assertEquals("Carrer Gran 1, Girona, Girona (província), Spain", model.formattedAddress)
    }

    @Test
    fun `formattedAddress skips components that are blank or absent`() {
        val model = entity(address = null, city = "Girona", region = null, country = "Spain").toUiModel()

        assertEquals("Girona, Spain", model.formattedAddress)
    }

    @Test
    fun `links are carried through as stored, already validated on import`() {
        val model = entity(website = "https://example.com", instagram = "cal_ferran").toUiModel()

        assertEquals("https://example.com", model.website)
        assertEquals("cal_ferran", model.instagram)
    }

    /** Drives whether the detail screen draws a Notes card at all. */
    @Test
    fun `notes come from the latest visit, with a blank one treated as none`() {
        assertNull(entity().toUiModel().notes)
        assertNull(entity().toUiModel(latestVisit = visit(notes = "   ")).notes)
        assertEquals("Ask for the burrata", entity().toUiModel(latestVisit = visit(notes = "Ask for the burrata")).notes)
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
    fun `visited is true only when a latest visit is passed in`() {
        assertTrue(entity().toUiModel(latestVisit = visit()).visited)
        assertFalse(entity().toUiModel(latestVisit = null).visited)
    }

    /** Drives whether a row/card draws the stored photo instead of the cuisine badge. */
    @Test
    fun `photoPath is carried through unchanged, defaulting to null`() {
        assertNull(entity().toUiModel().photoPath)
        assertEquals(
            "/data/user/0/com.saatxi.eatapp/files/photos/a.jpg",
            entity().toUiModel(photoPath = "/data/user/0/com.saatxi.eatapp/files/photos/a.jpg").photoPath
        )
    }
}
