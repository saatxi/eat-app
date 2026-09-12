package com.saatxi.eatapp.data.share

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RestaurantImportReaderTest {

    private fun export(name: String, priceRange: Int = 2, visits: List<VisitExport> = emptyList()) = RestaurantExport(
        name = name,
        cuisineType = "mediterranean",
        streetAddress = null,
        priceRange = priceRange,
        visits = visits
    )

    private fun jsonOf(shareFile: RestaurantShareFile): String =
        Json.encodeToString(RestaurantShareFile.serializer(), shareFile)

    @Test
    fun `reads a valid single-restaurant file`() {
        val outcome = RestaurantImportReader.read(jsonOf(RestaurantShareFile(restaurants = listOf(export("Cal Ferran")))))

        val success = outcome as ImportOutcome.Success
        assertEquals(listOf("Cal Ferran"), success.restaurants.map { it.restaurant.name })
        assertEquals(0, success.skippedCount)
    }

    @Test
    fun `reads a valid multi-restaurant file`() {
        val outcome = RestaurantImportReader.read(
            jsonOf(RestaurantShareFile(restaurants = listOf(export("Cal Ferran"), export("Bar Nil"))))
        )

        val success = outcome as ImportOutcome.Success
        assertEquals(listOf("Cal Ferran", "Bar Nil"), success.restaurants.map { it.restaurant.name })
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
                restaurants = listOf(export("Cal Ferran"), export(name = "  "), export("Bar Nil", priceRange = 9))
            )
        )

        val outcome = RestaurantImportReader.read(json) as ImportOutcome.Success

        assertEquals(listOf("Cal Ferran"), outcome.restaurants.map { it.restaurant.name })
        assertEquals(2, outcome.skippedCount)
    }

    @Test
    fun `never reuses an id from the file`() {
        val json = """{"format":"${RestaurantShareFile.FORMAT}","restaurants":[{"name":"Cal Ferran","cuisineType":"mediterranean","priceRange":2,"id":"not-a-real-id"}]}"""

        val outcome = RestaurantImportReader.read(json) as ImportOutcome.Success

        assertNotEquals("not-a-real-id", outcome.restaurants.single().restaurant.id)
    }

    // --- Visits -------------------------------------------------------------

    @Test
    fun `pairs each restaurant with its own valid visits`() {
        val json = jsonOf(
            RestaurantShareFile(
                restaurants = listOf(
                    export("Cal Ferran", visits = listOf(VisitExport(visitDate = 1L, rating = 4)))
                )
            )
        )

        val outcome = RestaurantImportReader.read(json) as ImportOutcome.Success

        assertEquals(listOf(VisitExport(visitDate = 1L, rating = 4)), outcome.restaurants.single().visits)
    }

    @Test
    fun `drops a row whose visit has an out-of-range rating`() {
        val json = jsonOf(
            RestaurantShareFile(
                restaurants = listOf(export("Cal Ferran", visits = listOf(VisitExport(visitDate = 1L, rating = 9))))
            )
        )

        val outcome = RestaurantImportReader.read(json) as ImportOutcome.Success

        assertTrue(outcome.restaurants.isEmpty())
        assertEquals(1, outcome.skippedCount)
    }

    // --- Tags (F-59) ------------------------------------------------------

    @Test
    fun `pairs each restaurant with its own validated tags`() {
        val json = jsonOf(
            RestaurantShareFile(restaurants = listOf(export("Cal Ferran").copy(tags = listOf("Terraza", "has,comma"))))
        )

        val outcome = RestaurantImportReader.read(json) as ImportOutcome.Success

        assertEquals(listOf("Terraza"), outcome.restaurants.single().tags)
    }
}
