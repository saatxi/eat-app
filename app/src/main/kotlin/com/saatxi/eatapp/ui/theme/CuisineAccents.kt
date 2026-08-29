package com.saatxi.eatapp.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/** A container colour and the colour that is legible on top of it. */
@Immutable
data class CuisineTint(val container: Color, val onContainer: Color)

/**
 * The accent set of the active palette, published alongside the `ColorScheme`
 * because it is theme data that Material's scheme has no room for.
 *
 * Cuisines used to be spread over the three container roles, which meant 24
 * cuisines cycling through the same three colours — the list read as striped
 * rather than varied. Eight accents is enough that a screenful of rows rarely
 * repeats, while still being a hand-checked set rather than a hash of the key.
 */
@Immutable
data class CuisineAccents(val slots: List<CuisineTint>) {
    init {
        require(slots.size == CUISINE_ACCENT_COUNT) {
            "expected $CUISINE_ACCENT_COUNT accents, got ${slots.size}"
        }
    }

    /** Wraps, so any index is valid and the caller never has to bounds-check. */
    operator fun get(index: Int): CuisineTint = slots[index.mod(slots.size)]
}

/**
 * Static rather than dynamic: the accents only change when the whole theme
 * changes, at which point everything recomposes anyway.
 */
val LocalCuisineAccents = staticCompositionLocalOf<CuisineAccents> {
    error("No CuisineAccents provided — wrap the content in EatAppTheme")
}
