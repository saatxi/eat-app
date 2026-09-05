package com.saatxi.eatapp.data.prefs

import android.os.Looper
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import com.saatxi.eatapp.ui.settings.AppLanguage
import java.util.Locale
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * [AppCompatLocaleManager] reads/writes through `AppCompatDelegate`'s own
 * static locale state rather than anything this app persists itself — see
 * its kdoc for why. Needs Robolectric: `AppCompatDelegate` isn't plain
 * Kotlin.
 */
@RunWith(RobolectricTestRunner::class)
class AppLocaleManagerTest {

    private val manager: AppLocaleManager = AppCompatLocaleManager()

    /** `AppCompatDelegate`'s applied-locales state is process-static, so each test must leave it clean. */
    @After
    fun tearDown() {
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.getEmptyLocaleList())
    }

    // Forces AppCompatDelegate's own compat storage path rather than delegating
    // to the framework's per-app LocaleManager (API 33+): the latter needs a
    // live Activity to actually apply under Robolectric, which this headless
    // test has no reason to stand up just to read a locale back.
    @Config(sdk = [30])
    @Test
    fun `setLanguage then getLanguage round-trips for every language`() {
        AppLanguage.entries.forEach { language ->
            manager.setLanguage(language)
            shadowOf(Looper.getMainLooper()).idle()

            assertEquals(language, manager.getLanguage())
        }
    }

    @Test
    fun `falls back to the device's language when nothing has been explicitly picked yet`() {
        val previousDefault = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag(AppLanguage.SPANISH.tag))

            assertEquals(AppLanguage.SPANISH, manager.getLanguage())
        } finally {
            Locale.setDefault(previousDefault)
        }
    }

    @Test
    fun `falls back to English when the device language is not one of the supported three`() {
        val previousDefault = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("de"))

            assertEquals(AppLanguage.Default, manager.getLanguage())
        } finally {
            Locale.setDefault(previousDefault)
        }
    }
}
