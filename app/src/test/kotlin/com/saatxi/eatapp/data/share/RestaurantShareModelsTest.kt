package com.saatxi.eatapp.data.share

import com.saatxi.eatapp.data.local.MAX_TAGS_PER_RESTAURANT
import com.saatxi.eatapp.data.local.Restaurant
import com.saatxi.eatapp.data.local.Visit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RestaurantShareModelsTest {

    private fun restaurant(
        name: String = "Cal Ferran",
        cuisineType: String = "mediterranean",
        address: String? = "Rambla 1",
        priceRange: Int = 2,
        website: String? = null,
        instagram: String? = null,
        city: String? = null,
        region: String? = null,
        country: String? = null
    ) = Restaurant(
        id = "7",
        name = name,
        cuisineType = cuisineType,
        streetAddress = address,
        priceRange = priceRange,
        website = website,
        instagram = instagram,
        city = city,
        region = region,
        country = country
    )

    private fun visit(rating: Int = 4, notes: String? = null, visitDate: Long = 1_000L) =
        Visit(id = "v1", restaurantId = "7", visitDate = visitDate, rating = rating, notes = notes)

    // --- Restaurant -> RestaurantExport --------------------------------

    @Test
    fun `toExport carries every field except id and searchText`() {
        val export = restaurant(website = "https://example.com", instagram = "cal_ferran").toExport()

        assertEquals("Cal Ferran", export.name)
        assertEquals("mediterranean", export.cuisineType)
        assertEquals("Rambla 1", export.streetAddress)
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
        val export = RestaurantExport(name = "Cal Ferran", cuisineType = "mediterranean", priceRange = 2)

        assertNull(export.city)
        assertNull(export.region)
        assertNull(export.country)
    }

    @Test
    fun `toExport carries a want-to-try restaurant with no visits`() {
        val export = restaurant().toExport(visits = emptyList())

        assertEquals(emptyList<VisitExport>(), export.visits)
    }

    @Test
    fun `visits default to empty when a share file predates the field`() {
        val export = RestaurantExport(name = "Cal Ferran", cuisineType = "mediterranean", priceRange = 2)

        assertEquals(emptyList<VisitExport>(), export.visits)
    }

    @Test
    fun `toExport carries each visit's date, rating and notes`() {
        val export = restaurant().toExport(visits = listOf(visit(rating = 4, notes = "Ask for the burrata", visitDate = 123L)))

        assertEquals(listOf(VisitExport(visitDate = 123L, rating = 4, notes = "Ask for the burrata")), export.visits)
    }

    // --- RestaurantExport -> Restaurant, which is where untrusted data is validated ---

    @Test
    fun `toRestaurantOrNull accepts a fully valid export and uses the given id`() {
        val export = restaurant().toExport()

        val result = export.toRestaurantOrNull(id = "fresh-id")

        assertEquals("fresh-id", result?.id)
        assertEquals("Cal Ferran", result?.name)
    }

    @Test
    fun `toRestaurantOrNull rejects a blank name`() {
        val export = RestaurantExport(name = "  ", cuisineType = "mediterranean", priceRange = 1)

        assertNull(export.toRestaurantOrNull(id = "x"))
    }

    @Test
    fun `toRestaurantOrNull rejects a blank cuisine`() {
        val export = RestaurantExport(name = "Cal Ferran", cuisineType = "", priceRange = 1)

        assertNull(export.toRestaurantOrNull(id = "x"))
    }

    @Test
    fun `toRestaurantOrNull rejects an out-of-range price`() {
        assertNull(RestaurantExport(name = "A", cuisineType = "bar", priceRange = 5).toRestaurantOrNull(id = "x"))
        assertNull(RestaurantExport(name = "A", cuisineType = "bar", priceRange = -1).toRestaurantOrNull(id = "x"))
    }

    @Test
    fun `toRestaurantOrNull rejects a row whose visit has an out-of-range rating`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", priceRange = 1,
            visits = listOf(VisitExport(visitDate = 1L, rating = 9))
        )

        assertNull(export.toRestaurantOrNull(id = "x"))
    }

    @Test
    fun `toRestaurantOrNull drops an unsafe website rather than the whole row`() {
        val export = RestaurantExport(name = "A", cuisineType = "bar", priceRange = 1, website = "javascript:alert(1)")

        assertEquals(null, export.toRestaurantOrNull(id = "x")?.website)
    }

    @Test
    fun `toRestaurantOrNull drops an unsafe instagram handle rather than the whole row`() {
        val export = RestaurantExport(name = "A", cuisineType = "bar", priceRange = 1, instagram = "not a handle!")

        assertEquals(null, export.toRestaurantOrNull(id = "x")?.instagram)
    }

    @Test
    fun `toRestaurantOrNull trims whitespace from name, cuisine and address`() {
        val export = RestaurantExport(
            name = "  Cal Ferran  ", cuisineType = " mediterranean ", streetAddress = "  Rambla 1  ",
            priceRange = 1
        )

        val result = export.toRestaurantOrNull(id = "x")

        assertEquals("Cal Ferran", result?.name)
        assertEquals("mediterranean", result?.cuisineType)
        assertEquals("Rambla 1", result?.streetAddress)
    }

    @Test
    fun `toRestaurantOrNull treats a blank address as no address`() {
        val export = RestaurantExport(name = "A", cuisineType = "bar", streetAddress = "   ", priceRange = 1)

        assertNull(export.toRestaurantOrNull(id = "x")?.streetAddress)
    }

    @Test
    fun `toRestaurantOrNull trims whitespace from city, region and country`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", priceRange = 1,
            city = "  Girona  ", region = "  Girona (província)  ", country = "  Spain  "
        )

        val result = export.toRestaurantOrNull(id = "x")

        assertEquals("Girona", result?.city)
        assertEquals("Girona (província)", result?.region)
        assertEquals("Spain", result?.country)
    }

    @Test
    fun `toRestaurantOrNull treats blank city, region or country as absent`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", priceRange = 1,
            city = "   ", region = "   ", country = "   "
        )

        val result = export.toRestaurantOrNull(id = "x")

        assertNull(result?.city)
        assertNull(result?.region)
        assertNull(result?.country)
    }

    // --- Visits -----------------------------------------------------------

    @Test
    fun `toValidatedVisits drops a visit with an out-of-range rating rather than the whole row`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", priceRange = 1,
            visits = listOf(VisitExport(visitDate = 1L, rating = 4), VisitExport(visitDate = 2L, rating = 9))
        )

        assertEquals(listOf(VisitExport(visitDate = 1L, rating = 4)), export.toValidatedVisits())
    }

    // --- Tags (F-59) ----------------------------------------------------

    @Test
    fun `toExport carries the given tags`() {
        val export = restaurant().toExport(tags = listOf("Terraza", "Brunch"))

        assertEquals(listOf("Terraza", "Brunch"), export.tags)
    }

    @Test
    fun `tags default to empty when a share file predates the field`() {
        val export = RestaurantExport(name = "Cal Ferran", cuisineType = "mediterranean", priceRange = 2)

        assertEquals(emptyList<String>(), export.tags)
    }

    @Test
    fun `toValidatedTagNames trims and drops blank tags`() {
        val export = RestaurantExport(name = "A", cuisineType = "bar", priceRange = 1, tags = listOf("  Terraza  ", "", "   "))

        assertEquals(listOf("Terraza"), export.toValidatedTagNames())
    }

    @Test
    fun `toValidatedTagNames drops a tag containing a comma rather than the whole row`() {
        val export = RestaurantExport(name = "A", cuisineType = "bar", priceRange = 1, tags = listOf("Terraza", "has,a,comma"))

        assertEquals(listOf("Terraza"), export.toValidatedTagNames())
    }

    @Test
    fun `toValidatedTagNames folds case-insensitive duplicates into one`() {
        val export = RestaurantExport(name = "A", cuisineType = "bar", priceRange = 1, tags = listOf("Terraza", "terraza", "TERRAZA"))

        assertEquals(listOf("Terraza"), export.toValidatedTagNames())
    }

    @Test
    fun `toValidatedTagNames caps the number of tags from one row`() {
        val export = RestaurantExport(
            name = "A", cuisineType = "bar", priceRange = 1,
            tags = (1..MAX_TAGS_PER_RESTAURANT + 5).map { "Tag$it" }
        )

        assertEquals(MAX_TAGS_PER_RESTAURANT, export.toValidatedTagNames().size)
    }
}
