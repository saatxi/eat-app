package com.saatxi.eatapp.data.local

import androidx.annotation.StringRes
import com.saatxi.eatapp.R

/**
 * The closed vocabulary of cuisine types the app understands.
 *
 * The `restaurants.cuisineType` column of the synced `.db` stores [key] — a
 * stable, language-independent identifier — never a display label. Only
 * [labelRes] is ever translated, so adding a language means adding a
 * `values-xx/strings.xml` and nothing else: the data file is never touched.
 *
 * The vocabulary is documented for data authors in the README's
 * "Data source & updating restaurant data" section. Keep the two in sync.
 */
enum class Cuisine(val key: String, @StringRes val labelRes: Int) {
    // Origin
    MEDITERRANEAN("mediterranean", R.string.cuisine_mediterranean),
    SPANISH("spanish", R.string.cuisine_spanish),
    CATALAN("catalan", R.string.cuisine_catalan),
    BASQUE("basque", R.string.cuisine_basque),
    ITALIAN("italian", R.string.cuisine_italian),
    JAPANESE("japanese", R.string.cuisine_japanese),
    CHINESE("chinese", R.string.cuisine_chinese),
    ASIAN("asian", R.string.cuisine_asian),
    INDIAN("indian", R.string.cuisine_indian),
    MIDDLE_EASTERN("middle_eastern", R.string.cuisine_middle_eastern),
    AMERICAN("american", R.string.cuisine_american),
    SEAFOOD("seafood", R.string.cuisine_seafood),

    // Venue / meal type
    BAR("bar", R.string.cuisine_bar),
    BEER_BAR("beer_bar", R.string.cuisine_beer_bar),
    WINE_BAR("wine_bar", R.string.cuisine_wine_bar),
    CAFE("cafe", R.string.cuisine_cafe),
    BAKERY("bakery", R.string.cuisine_bakery),
    DESSERT("dessert", R.string.cuisine_dessert),
    BREAKFAST("breakfast", R.string.cuisine_breakfast),
    BRUNCH("brunch", R.string.cuisine_brunch),
    GRILL("grill", R.string.cuisine_grill),
    FAST_FOOD("fast_food", R.string.cuisine_fast_food),
    FINE_DINING("fine_dining", R.string.cuisine_fine_dining),
    VEGETARIAN("vegetarian", R.string.cuisine_vegetarian);

    companion object {
        private val byKey = entries.associateBy { it.key }

        /**
         * Resolves a raw `cuisineType` value, or null when the file uses a key
         * this build doesn't know. Callers must degrade gracefully rather than
         * fail: an unrecognised key still shows the raw string and a generic
         * icon, so a newer data file never breaks an older app.
         */
        fun fromKey(key: String?): Cuisine? =
            key?.trim()?.lowercase()?.let(byKey::get)
    }
}
