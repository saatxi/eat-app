package com.albertferran.eatapp.baselineprofile

import androidx.benchmark.macro.junit4.BaselineProfileRule
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Direction
import androidx.test.uiautomator.Until
import org.junit.Rule
import org.junit.Test

/**
 * Generates app/src/main/baseline-prof.txt by exercising cold startup, a list
 * scroll and a list -> detail navigation. Needs a connected device or
 * emulator running API 28+: gradlew.bat :app:generateBaselineProfile
 */
class BaselineProfileGenerator {
    @get:Rule
    val baselineProfileRule = BaselineProfileRule()

    @Test
    fun generate() = baselineProfileRule.collect(
        packageName = "com.albertferran.eatapp"
    ) {
        pressHome()
        startActivityAndWait()

        // Cold start lands on the restaurant list; give the initial DB read /
        // first sync a moment before touching it.
        device.wait(Until.hasObject(By.scrollable(true)), 5_000)
        val list = device.findObject(By.scrollable(true)) ?: return@collect
        list.fling(Direction.DOWN)
        device.waitForIdle()

        // Open a restaurant's detail screen, then return to the list.
        val row = device.findObject(By.clickable(true)) ?: return@collect
        row.click()
        device.waitForIdle()
        device.pressBack()
        device.waitForIdle()
    }
}
