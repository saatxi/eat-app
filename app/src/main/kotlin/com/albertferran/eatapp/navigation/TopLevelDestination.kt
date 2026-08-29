package com.albertferran.eatapp.navigation

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.outlined.Casino
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.ui.graphics.vector.ImageVector
import com.albertferran.eatapp.R

/**
 * The four destinations reachable from the bottom bar / navigation rail. The
 * filled/outline icon pair by selection state is Now in Android's pattern.
 */
enum class TopLevelDestination(
    val route: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector,
    @StringRes val labelRes: Int
) {
    LIST("list", Icons.Filled.Restaurant, Icons.Outlined.Restaurant, R.string.nav_restaurants),
    FAVORITES("favorites", Icons.Filled.Favorite, Icons.Outlined.FavoriteBorder, R.string.nav_favorites),
    ROULETTE("roulette", Icons.Filled.Casino, Icons.Outlined.Casino, R.string.nav_roulette),
    SETTINGS("settings", Icons.Filled.Settings, Icons.Outlined.Settings, R.string.nav_settings)
}
