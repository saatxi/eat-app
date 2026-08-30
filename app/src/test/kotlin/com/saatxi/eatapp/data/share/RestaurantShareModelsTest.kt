package com.saatxi.eatapp.data.share

import com.saatxi.eatapp.data.local.Restaurant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RestaurantShareModelsTest {

    private fun restaurant(
        name: String = "Cal Ferran",
        cuisineType: String = "mediterranean",
        address: String? = "Rambla 1",
        rating: Int = 4,
        priceRange: Int = 2,
        website: String? = null,
        instagram: String? = null
    ) = Restaurant(
        id = 7,
        name = name,
        cuisineType = cuisineType,
        address = address,
        rating = rating,
        priceRange = priceRange,
        website = website,
        instagram = instagram
    )

    // --- Restaurant -> RestaurantExport --------------------------------

    @Test
    fun `toExport carries every field except id and searchText`() {
        val export = restaurant(website = "https://example.com", instagram = "cal_ferran").toExport()

        assertEquals("Cal Ferran", export.name)
        assertEquals("mediterranean", export.cuisineType)
        assertEquals("Rambla 1", export.address)
        assertEquals(4, export.rating)
        assertEquals(2, export.priceRange)
        assertEquals("https://example.com", export.website)
        assertEquals("cal_ferran", export.instagram)
    }

    // --- RestaurantExport -> Restaurant, which is where untrusted data is validated ---

    @Test
    fun `toRestaurantOrNull accepts a fully valid export`() {
        val export = restaurant().toExport()

        val result = export.toRestaurantOrNull()

        assertEquals(0L, result?.id)
        assertEquals("Cal Ferran", result?.name)
    }

    @Test
    fun `toRestaurantOrNull rejects a blank name`() {
        val export = RestaurantExport(name = "  ", cuisineType = "mediterranean", rating = 3, priceRange = 1)

        assertNull(export.toRestaurantOrNull())
    }

    @Test
    fun `toRestaurantOrNull rejects a blank cuisine`() {
        val export = RestaurantExport(name = "Cal Ferran", cuisineType = "", rating = 3, priceRange = 1)

        assertNull(export.toRestaurantOrNull())
    }

    @Test
    fun `toRestaurantOrNull rejects an out-of-range rating or price`() {
        assertNull(RestaurantExport(name = "A", cuisineType = "bar", rating = 6, priceRange = 1).toRestaurantOrNull())
        assertNull(RestaurantExport(name = "A", cuisineType = "bar", rating = -1, priceRange = 1).toRestaurantOrNull())
        assertNull(RestaurantExport(name = "A", cuisineType = "bar", rating = 3, priceRange = 5).toRestaurantOrNull())
    }

    @Test
    fun `toRestaurantOrNull drops an unsafe website rather than the whole row`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", rating = 3, priceRange = 1,
            website = "javascript:alert(1)"
        )

        assertEquals(null, export.toRestaurantOrNull()?.website)
    }

    @Test
    fun `toRestaurantOrNull drops an unsafe instagram handle rather than the whole row`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", rating = 3, priceRange = 1,
            instagram = "not a handle!"
        )

        assertEquals(null, export.toRestaurantOrNull()?.instagram)
    }

    @Test
    fun `toRestaurantOrNull trims whitespace from name, cuisine and address`() {
        val export = RestaurantExport(
            name = "  Cal Ferran  ", cuisineType = " mediterranean ", address = "  Rambla 1  ",
            rating = 3, priceRange = 1
        )

        val result = export.toRestaurantOrNull()

        assertEquals("Cal Ferran", result?.name)
        assertEquals("mediterranean", result?.cuisineType)
        assertEquals("Rambla 1", result?.address)
    }

    @Test
    fun `toRestaurantOrNull treats a blank address as no address`() {
        val export = RestaurantExport(name = "A", cuisineType = "bar", address = "   ", rating = 3, priceRange = 1)

        assertNull(export.toRestaurantOrNull()?.address)
    }
}
