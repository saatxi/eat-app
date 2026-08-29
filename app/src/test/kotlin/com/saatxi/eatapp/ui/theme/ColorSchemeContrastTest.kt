package com.saatxi.eatapp.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * Every on-colour must be legible on the colour it sits on.
 *
 * This exists because the palette it replaced wasn't. `onSecondaryContainer`
 * reused tone 40 over a tone 80 container — about 2.9:1, well under the 4.5:1
 * WCAG AA needs for normal text — which showed up in the selected cuisine
 * filter chips and the badge behind every list row's icon. Nothing caught it,
 * because nothing was checking.
 *
 * Pure maths on plain `Color` values, so it runs on the JVM with no Compose
 * runtime and no Robolectric.
 */
class ColorSchemeContrastTest {

    /** WCAG 2.1 AA for normal-size text. */
    private val minimumContrast = 4.5

    @Test
    fun `every palette is legible in light mode`() {
        AppPalette.entries.forEach { palette ->
            assertScheme("${palette.name} light", palette.tones.lightScheme())
        }
    }

    @Test
    fun `every palette is legible in dark mode`() {
        AppPalette.entries.forEach { palette ->
            assertScheme("${palette.name} dark", palette.tones.darkScheme())
        }
    }

    /**
     * The cuisine accents are drawn as an icon on a filled badge, so they carry
     * the same burden as the container roles.
     */
    @Test
    fun `every cuisine accent is legible in both modes`() {
        AppPalette.entries.forEach { palette ->
            listOf(
                "light" to palette.tones.lightAccents(),
                "dark" to palette.tones.darkAccents()
            ).forEach { (mode, accents) ->
                accents.slots.forEachIndexed { index, tint ->
                    assertContrast(
                        "${palette.name} $mode accent $index",
                        tint.onContainer,
                        tint.container
                    )
                }
            }
        }
    }

    /** Guards the invariant the accent indexing in `cuisineTint` relies on. */
    @Test
    fun `every palette defines the same number of accents`() {
        AppPalette.entries.forEach { palette ->
            assertTrue(
                "${palette.name} has ${palette.tones.accents.size} accents",
                palette.tones.accents.size == CUISINE_ACCENT_COUNT
            )
        }
    }

    private fun assertScheme(label: String, scheme: ColorScheme) = with(scheme) {
        assertContrast("$label onPrimary", onPrimary, primary)
        assertContrast("$label onPrimaryContainer", onPrimaryContainer, primaryContainer)
        assertContrast("$label onSecondary", onSecondary, secondary)
        assertContrast("$label onSecondaryContainer", onSecondaryContainer, secondaryContainer)
        assertContrast("$label onTertiary", onTertiary, tertiary)
        assertContrast("$label onTertiaryContainer", onTertiaryContainer, tertiaryContainer)
        assertContrast("$label onError", onError, error)
        assertContrast("$label onErrorContainer", onErrorContainer, errorContainer)
        assertContrast("$label onBackground", onBackground, background)
        assertContrast("$label onSurface", onSurface, surface)
        assertContrast("$label onSurfaceVariant", onSurfaceVariant, surfaceVariant)
        assertContrast("$label inverseOnSurface", inverseOnSurface, inverseSurface)
        // Body text sits on every surface tier, not just `surface` itself.
        assertContrast("$label onSurface over surfaceContainer", onSurface, surfaceContainer)
        assertContrast("$label onSurface over surfaceContainerHighest", onSurface, surfaceContainerHighest)
        assertContrast("$label onSurface over surfaceContainerLowest", onSurface, surfaceContainerLowest)
    }

    private fun assertContrast(label: String, foreground: Color, background: Color) {
        val ratio = contrastRatio(foreground, background)
        assertTrue(
            "$label: contrast is %.2f:1, needs at least %.1f:1".format(ratio, minimumContrast),
            ratio >= minimumContrast
        )
    }

    /** WCAG relative-luminance contrast ratio, between 1:1 and 21:1. */
    private fun contrastRatio(a: Color, b: Color): Double {
        val luminanceA = relativeLuminance(a)
        val luminanceB = relativeLuminance(b)
        return (max(luminanceA, luminanceB) + 0.05) / (min(luminanceA, luminanceB) + 0.05)
    }

    private fun relativeLuminance(color: Color): Double =
        0.2126 * linearize(color.red) +
            0.7152 * linearize(color.green) +
            0.0722 * linearize(color.blue)

    private fun linearize(channel: Float): Double {
        val value = channel.toDouble()
        return if (value <= 0.03928) value / 12.92 else ((value + 0.055) / 1.055).pow(2.4)
    }
}
