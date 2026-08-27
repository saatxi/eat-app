package com.albertferran.eatapp.navigation

import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionLayout
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.albertferran.eatapp.ui.common.LocalNavAnimatedVisibilityScope
import com.albertferran.eatapp.ui.common.LocalSharedTransitionScope
import com.albertferran.eatapp.ui.common.SCREEN_TRANSITION_DURATION_MS
import com.albertferran.eatapp.ui.detail.RestaurantDetailScreen
import com.albertferran.eatapp.ui.list.RestaurantListScreen

private const val ARG_RESTAURANT_ID = "restaurantId"

private object Routes {
    const val LIST = "list"
    const val DETAIL = "detail/{restaurantId}"
}

private fun detailRoute(restaurantId: Long) = "detail/$restaurantId"

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun EatAppNavHost(navController: NavHostController = rememberNavController()) {
    // Wraps the whole graph so an element can be matched across two destinations;
    // the scope is published as a CompositionLocal rather than passed down, see
    // ui/common/SharedTransition.kt.
    SharedTransitionLayout {
        CompositionLocalProvider(LocalSharedTransitionScope provides this) {
            NavHost(
                navController = navController,
                startDestination = Routes.LIST,
                // The cuisine badge carries the motion between the screens, so the
                // destinations themselves only cross-fade. The default horizontal
                // slide would drag the badge sideways along with everything else.
                enterTransition = { fadeIn(tween(SCREEN_TRANSITION_DURATION_MS)) },
                exitTransition = { fadeOut(tween(SCREEN_TRANSITION_DURATION_MS)) },
                popEnterTransition = { fadeIn(tween(SCREEN_TRANSITION_DURATION_MS)) },
                popExitTransition = { fadeOut(tween(SCREEN_TRANSITION_DURATION_MS)) }
            ) {
                composable(Routes.LIST) {
                    val animatedVisibilityScope = this
                    CompositionLocalProvider(
                        LocalNavAnimatedVisibilityScope provides animatedVisibilityScope
                    ) {
                        RestaurantListScreen(
                            onOpenRestaurant = { id -> navController.navigate(detailRoute(id)) }
                        )
                    }
                }
                composable(
                    route = Routes.DETAIL,
                    arguments = listOf(navArgument(ARG_RESTAURANT_ID) { type = NavType.LongType })
                ) {
                    val animatedVisibilityScope = this
                    CompositionLocalProvider(
                        LocalNavAnimatedVisibilityScope provides animatedVisibilityScope
                    ) {
                        RestaurantDetailScreen(
                            onBack = { navController.popBackStack() }
                        )
                    }
                }
            }
        }
    }
}
