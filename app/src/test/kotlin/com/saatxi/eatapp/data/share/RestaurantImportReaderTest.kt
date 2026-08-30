package com.saatxi.eatapp.data.share

import com.saatxi.eatapp.data.local.Restaurant
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RestaurantImportReaderTest {

    private fun export(name: String, rating: Int = 3, priceRange: Int = 2) = RestaurantExport(
        name = name,
        cuisineType = "mediterranean",
        address = null,
        rating = rating,
        priceRange = priceRange
    )

    private fun jsonOf(shareFile: RestaurantShareFile): String =
        Json.encodeToString(RestaurantShareFile.serializer(), shareFile)

    @Test
    fun `reads a valid single-restaurant file`() {
        val outcome = RestaurantImportReader.read(jsonOf(RestaurantShareFile(restaurants = listOf(export("Cal Ferran")))))

        val success = outcome as ImportOutcome.Success
        assertEquals(listOf("Cal Ferran"), success.restaurants.map(Restaurant::name))
        assertEquals(0, success.skippedCount)
    }

    @Test
    fun `reads a valid multi-restaurant file`() {
        val outcome = RestaurantImportReader.read(
            jsonOf(RestaurantShareFile(restaurants = listOf(export("Cal Ferran"), export("Bar Nil"))))
        )

        val success = outcome as ImportOutcome.Success
        assertEquals(listOf("Cal Ferran", "Bar Nil"), success.restaurants.map(Restaurant::name))
    }

    @Test
    fun `an empty restaurant list is a valid, successful import of nothing`() {
        val outcome = RestaurantImportReader.read(jsonOf(RestaurantShareFile(restaurants = emptyList())))

        val success = outcome as ImportOutcome.Success
        assertTrue(success.restaurants.isEmpty())
        assertEquals(0, success.skippedCount)
    }

    @Test
    fun `rejects a file with the wrong format tag`() {
        val json = """{"format":"something-else","restaurants":[]}"""

        val outcome = RestaurantImportReader.read(json)

        assertEquals(ImportOutcome.Error(ImportFailureReason.INVALID_FILE), outcome)
    }

    @Test
    fun `rejects malformed JSON instead of crashing`() {
        val outcome = RestaurantImportReader.read("not json at all")

        assertEquals(ImportOutcome.Error(ImportFailureReason.INVALID_FILE), outcome)
    }

    @Test
    fun `rejects a plain unrelated JSON document`() {
        val outcome = RestaurantImportReader.read("""{"hello":"world"}""")

        assertEquals(ImportOutcome.Error(ImportFailureReason.INVALID_FILE), outcome)
    }

    @Test
    fun `drops an invalid row but keeps the rest of the file, reporting the count`() {
        val json = jsonOf(
            RestaurantShareFile(
                restaurants = listOf(export("Cal Ferran"), export(name = "  "), export("Bar Nil", rating = 9))
            )
        )

        val outcome = RestaurantImportReader.read(json) as ImportOutcome.Success

        assertEquals(listOf("Cal Ferran"), outcome.restaurants.map(Restaurant::name))
        assertEquals(2, outcome.skippedCount)
    }

    @Test
    fun `never assigns an id from the file`() {
        val json = """{"format":"${RestaurantShareFile.FORMAT}","restaurants":[{"name":"Cal Ferran","cuisineType":"mediterranean","rating":3,"priceRange":2,"id":999}]}"""

        val outcome = RestaurantImportReader.read(json) as ImportOutcome.Success

        assertEquals(0L, outcome.restaurants.single().id)
    }
}
