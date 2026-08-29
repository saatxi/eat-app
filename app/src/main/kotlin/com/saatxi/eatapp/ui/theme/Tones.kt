package com.saatxi.eatapp.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

/**
 * The tonal vocabulary a palette is built from.
 *
 * Material 3 derives every colour role from a small set of tones per family, so
 * a palette here declares tones and [PaletteTones.lightScheme] /
 * [PaletteTones.darkScheme] do the tone-to-role mapping once. Adding a fourth
 * palette is therefore a matter of listing tones, not of re-deriving which tone
 * `onSecondaryContainer` is supposed to use.
 *
 * Only the tones the roles actually consume are declared — there is no value in
 * carrying a full 0-100 ramp that nothing reads.
 */

/** Tones of a brand family (primary, secondary, tertiary). */
@Immutable
data class BrandTones(
    val t10: Color,
    val t20: Color,
    val t30: Color,
    val t40: Color,
    val t80: Color,
    val t90: Color,
    val t95: Color
)

/**
 * Tones of the neutral family, which the surface and background roles map to.
 * The steps are irregular because M3's surface container tiers are: light mode
 * reads 87-100, dark mode reads 4-24.
 */
@Immutable
data class NeutralTones(
    val t4: Color,
    val t6: Color,
    val t10: Color,
    val t12: Color,
    val t17: Color,
    val t20: Color,
    val t22: Color,
    val t24: Color,
    val t87: Color,
    val t90: Color,
    val t92: Color,
    val t94: Color,
    val t95: Color,
    val t96: Color,
    val t98: Color,
    val t100: Color
)

/** Tones of the neutral-variant family: outlines and `surfaceVariant`. */
@Immutable
data class NeutralVariantTones(
    val t30: Color,
    val t50: Color,
    val t60: Color,
    val t80: Color,
    val t90: Color
)

/**
 * One cuisine accent. Only three tones are needed: a container and its
 * on-colour, which swap roles between light and dark.
 */
@Immutable
data class AccentTones(
    val t10: Color,
    val t30: Color,
    val t90: Color
)

/** How many accents every palette must define. See [CuisineAccents]. */
const val CUISINE_ACCENT_COUNT = 8

@Immutable
data class PaletteTones(
    val primary: BrandTones,
    val secondary: BrandTones,
    val tertiary: BrandTones,
    val neutral: NeutralTones,
    val neutralVariant: NeutralVariantTones,
    /** Exactly [CUISINE_ACCENT_COUNT] entries, spread around the colour wheel. */
    val accents: List<AccentTones>
) {
    init {
        require(accents.size == CUISINE_ACCENT_COUNT) {
            "a palette must define exactly $CUISINE_ACCENT_COUNT accents, got ${accents.size}"
        }
    }
}
