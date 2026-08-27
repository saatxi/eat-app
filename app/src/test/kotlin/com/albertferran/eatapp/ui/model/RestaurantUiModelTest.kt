package com.albertferran.eatapp.ui.model

import com.albertferran.eatapp.data.local.Restaurant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
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
        priceRange: Int = 2
    ) = Restaurant(
        id = id,
        name = name,
        cuisineType = cuisineType,
        address = address,
        rating = rating,
        priceRange = priceRange
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
    fun `the rating becomes a fixed-length list of filled and empty stars`() {
        assertEquals(
            listOf(true, true, true, false, false),
            entity(rating = 3).toUiModel().stars
        )
        assertEquals(List(5) { false }, entity(rating = 0).toUiModel().stars)
        assertEquals(List(5) { true }, entity(rating = 5).toUiModel().stars)
    }

    @Test
    fun `a missing or blank address is null, so the screens skip the row`() {
        assertNull(entity(address = null).toUiModel().address)
        assertNull(entity(address = "   ").toUiModel().address)
        assertEquals("Carrer Gran 1", entity().toUiModel().address)
    }
}
