package com.saatxi.eatapp.data.share

import com.saatxi.eatapp.data.local.MAX_TAGS_PER_RESTAURANT
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
        visited: Boolean = true,
        website: String? = null,
        instagram: String? = null,
        notes: String? = null,
        city: String? = null,
        region: String? = null,
        country: String? = null
    ) = Restaurant(
        id = 7,
        name = name,
        cuisineType = cuisineType,
        streetAddress = address,
        rating = rating,
        priceRange = priceRange,
        visited = visited,
        website = website,
        instagram = instagram,
        notes = notes,
        city = city,
        region = region,
        country = country
    )

    // --- Restaurant -> RestaurantExport --------------------------------

    @Test
    fun `toExport carries every field except id and searchText`() {
        val export = restaurant(website = "https://example.com", instagram = "cal_ferran").toExport()

        assertEquals("Cal Ferran", export.name)
        assertEquals("mediterranean", export.cuisineType)
        assertEquals("Rambla 1", export.streetAddress)
        assertEquals(4, export.rating)
        assertEquals(2, export.priceRange)
        assertEquals("https://example.com", export.website)
        assertEquals("cal_ferran", export.instagram)
    }

    @Test
    fun `toExport carries city, region and country`() {
        val export = restaurant(city = "Girona", region = "Girona (província)", country = "Spain").toExport()

        assertEquals("Girona", export.city)
        assertEquals("Girona (província)", export.region)
        assertEquals("Spain", export.country)
    }

    @Test
    fun `city, region and country default to null when a share file predates the fields`() {
        // Mirrors decoding an older export whose JSON has no "city"/"region"/"country" keys at all.
        val export = RestaurantExport(name = "Cal Ferran", cuisineType = "mediterranean", rating = 4, priceRange = 2)

        assertNull(export.city)
        assertNull(export.region)
        assertNull(export.country)
    }

    @Test
    fun `toExport carries a want-to-try restaurant's visited flag through as false`() {
        val export = restaurant(visited = false).toExport()

        assertEquals(false, export.visited)
    }

    @Test
    fun `visited defaults to true when a share file predates the field`() {
        // Mirrors decoding an older export whose JSON has no "visited" key at all.
        val export = RestaurantExport(name = "Cal Ferran", cuisineType = "mediterranean", rating = 4, priceRange = 2)

        assertEquals(true, export.visited)
    }

    @Test
    fun `toExport carries notes through`() {
        val export = restaurant(notes = "Ask for the burrata").toExport()

        assertEquals("Ask for the burrata", export.notes)
    }

    @Test
    fun `notes default to null when a share file predates the field`() {
        // Mirrors decoding an older export whose JSON has no "notes" key at all.
        val export = RestaurantExport(name = "Cal Ferran", cuisineType = "mediterranean", rating = 4, priceRange = 2)

        assertNull(export.notes)
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
            name = "  Cal Ferran  ", cuisineType = " mediterranean ", streetAddress = "  Rambla 1  ",
            rating = 3, priceRange = 1
        )

        val result = export.toRestaurantOrNull()

        assertEquals("Cal Ferran", result?.name)
        assertEquals("mediterranean", result?.cuisineType)
        assertEquals("Rambla 1", result?.streetAddress)
    }

    @Test
    fun `toRestaurantOrNull treats a blank address as no address`() {
        val export = RestaurantExport(name = "A", cuisineType = "bar", streetAddress = "   ", rating = 3, priceRange = 1)

        assertNull(export.toRestaurantOrNull()?.streetAddress)
    }

    @Test
    fun `toRestaurantOrNull trims whitespace from city, region and country`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", rating = 3, priceRange = 1,
            city = "  Girona  ", region = "  Girona (província)  ", country = "  Spain  "
        )

        val result = export.toRestaurantOrNull()

        assertEquals("Girona", result?.city)
        assertEquals("Girona (província)", result?.region)
        assertEquals("Spain", result?.country)
    }

    @Test
    fun `toRestaurantOrNull treats blank city, region or country as absent`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", rating = 3, priceRange = 1,
            city = "   ", region = "   ", country = "   "
        )

        val result = export.toRestaurantOrNull()

        assertNull(result?.city)
        assertNull(result?.region)
        assertNull(result?.country)
    }

    @Test
    fun `toRestaurantOrNull trims whitespace from notes`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", rating = 3, priceRange = 1,
            notes = "  Ask for the burrata  "
        )

        assertEquals("Ask for the burrata", export.toRestaurantOrNull()?.notes)
    }

    @Test
    fun `toRestaurantOrNull treats a blank note as no note`() {
        val export = RestaurantExport(name = "A", cuisineType = "bar", rating = 3, priceRange = 1, notes = "   ")

        assertNull(export.toRestaurantOrNull()?.notes)
    }

    @Test
    fun `toRestaurantOrNull carries the visited flag through, both ways`() {
        val wantToTry = RestaurantExport(name = "A", cuisineType = "bar", rating = 3, priceRange = 1, visited = false)
        val visited = RestaurantExport(name = "B", cuisineType = "bar", rating = 3, priceRange = 1, visited = true)

        assertEquals(false, wantToTry.toRestaurantOrNull()?.visited)
        assertEquals(true, visited.toRestaurantOrNull()?.visited)
    }

    // --- Tags (F-59) ----------------------------------------------------

    @Test
    fun `toExport carries the given tags`() {
        val export = restaurant().toExport(tags = listOf("Terraza", "Brunch"))

        assertEquals(listOf("Terraza", "Brunch"), export.tags)
    }

    @Test
    fun `tags default to empty when a share file predates the field`() {
        // Mirrors decoding an older export whose JSON has no "tags" key at all.
        val export = RestaurantExport(name = "Cal Ferran", cuisineType = "mediterranean", rating = 4, priceRange = 2)

        assertEquals(emptyList<String>(), export.tags)
    }

    @Test
    fun `toValidatedTagNames trims and drops blank tags`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", rating = 3, priceRange = 1,
            tags = listOf("  Terraza  ", "", "   ")
        )

        assertEquals(listOf("Terraza"), export.toValidatedTagNames())
    }

    @Test
    fun `toValidatedTagNames drops a tag containing a comma rather than the whole row`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", rating = 3, priceRange = 1,
            tags = listOf("Terraza", "has,a,comma")
        )

        assertEquals(listOf("Terraza"), export.toValidatedTagNames())
    }

    @Test
    fun `toValidatedTagNames folds case-insensitive duplicates into one`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", rating = 3, priceRange = 1,
            tags = listOf("Terraza", "terraza", "TERRAZA")
        )

        assertEquals(listOf("Terraza"), export.toValidatedTagNames())
    }

    @Test
    fun `toValidatedTagNames caps the number of tags from one row`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", rating = 3, priceRange = 1,
            tags = (1..MAX_TAGS_PER_RESTAURANT + 5).map { "Tag$it" }
        )

        assertEquals(MAX_TAGS_PER_RESTAURANT, export.toValidatedTagNames().size)
    }
}
