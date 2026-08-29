package com.saatxi.eatapp.data.sync

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlin.random.Random
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [copyUpToLimit] is the download size cap from F-03, pulled out as a plain
 * function so it can be exercised without a network round trip.
 */
class RestaurantDatabaseSyncManagerTest {

    @Test
    fun `a stream under the limit copies through in full`() {
        val data = Random.nextBytes(1_000)
        val output = ByteArrayOutputStream()

        val fit = copyUpToLimit(ByteArrayInputStream(data), output, limit = 10_000)

        assertTrue(fit)
        assertArrayEquals(data, output.toByteArray())
    }

    @Test
    fun `a stream exactly at the limit copies through in full`() {
        val data = Random.nextBytes(10_000)
        val output = ByteArrayOutputStream()

        val fit = copyUpToLimit(ByteArrayInputStream(data), output, limit = 10_000)

        assertTrue(fit)
        assertArrayEquals(data, output.toByteArray())
    }

    @Test
    fun `a stream over the limit is rejected`() {
        val data = Random.nextBytes(10_001)
        val output = ByteArrayOutputStream()

        val fit = copyUpToLimit(ByteArrayInputStream(data), output, limit = 10_000)

        assertFalse(fit)
    }

    @Test
    fun `an empty stream copies through as fitting`() {
        val output = ByteArrayOutputStream()

        val fit = copyUpToLimit(ByteArrayInputStream(ByteArray(0)), output, limit = 10_000)

        assertTrue(fit)
        assertArrayEquals(ByteArray(0), output.toByteArray())
    }
}
