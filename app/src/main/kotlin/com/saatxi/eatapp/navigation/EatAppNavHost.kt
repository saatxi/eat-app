package com.saatxi.eatapp.navigation

import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionLayout
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.material3.Icon
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfoV2
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffoldDefaults
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteType
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavDestination
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.saatxi.eatapp.ui.common.LocalNavAnimatedVisibilityScope
import com.saatxi.eatapp.ui.common.LocalSharedTransitionScope
import com.saatxi.eatapp.ui.common.SCREEN_TRANSITION_DURATION_MS
import com.saatxi.eatapp.ui.detail.RestaurantDetailScreen
import com.saatxi.eatapp.ui.favorites.FavoritesScreen
import com.saatxi.eatapp.ui.list.RestaurantListScreen
import com.saatxi.eatapp.ui.roulette.RouletteScreen
import com.saatxi.eatapp.ui.settings.SettingsScreen

private const val ARG_RESTAURANT_ID = "restaurantId"

private object Routes {
    const val DETAIL = "detail/{restaurantId}"
}

private fun detailRoute(restaurantId: Long) = "detail/$restaurantId"

private fun NavDestination?.isTopLevelDestinationInHierarchy(destination: TopLevelDestination): Boolean =
    this?.hierarchy?.any { it.route == destination.route } == true

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun EatAppNavHost(navController: NavHostController = rememberNavController()) {
    val currentDestination = navController.currentBackStackEntryAsState().value?.destination
    // The bottom bar / rail has nowhere to live on the detail screen — it has no
    // tab of its own, it's reached by tapping into one of the other four.
    val isDetailRoute = currentDestination?.route == Routes.DETAIL

    // Wraps the whole graph so an element can be matched across two destinations;
    // the scope is published as a CompositionLocal rather than passed down, see
    // ui/common/SharedTransition.kt.
    SharedTransitionLayout {
        CompositionLocalProvider(LocalSharedTransitionScope provides this) {
            NavigationSuiteScaffold(
                navigationSuiteItems = {
                    TopLevelDestination.entries.forEach { destination ->
                        val selected = currentDestination.isTopLevelDestinationInHierarchy(destination)
                        item(
                            selected = selected,
                            onClick = {
                                navController.navigate(destination.route) {
                                    // Each tab keeps its own scroll position and filters,
                                    // rather than resetting every time it's revisited.
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = if (selected) destination.selectedIcon else destination.unselectedIcon,
                                    // No visible label (see below), so the icon alone
                                    // carries the accessible name instead.
                                    contentDescription = stringResource(destination.labelRes)
                                )
                            }
                        )
                    }
                },
                layoutType = if (isDetailRoute) {
                    NavigationSuiteType.None
                } else {
                    NavigationSuiteScaffoldDefaults.calculateFromAdaptiveInfo(currentWindowAdaptiveInfoV2())
                }
            ) {
                NavHost(
                    navController = navController,
                    startDestination = TopLevelDestination.LIST.route,
                    // The cuisine badge carries the motion between list and detail, so the
                    // destinations themselves only cross-fade. The default horizontal
                    // slide would drag the badge sideways along with everything else.
                    enterTransition = { fadeIn(tween(SCREEN_TRANSITION_DURATION_MS)) },
                    exitTransition = { fadeOut(tween(SCREEN_TRANSITION_DURATION_MS)) },
                    popEnterTransition = { fadeIn(tween(SCREEN_TRANSITION_DURATION_MS)) },
                    popExitTransition = { fadeOut(tween(SCREEN_TRANSITION_DURATION_MS)) }
                ) {
                    composable(TopLevelDestination.LIST.route) {
                        val animatedVisibilityScope = this
                        CompositionLocalProvider(
                            LocalNavAnimatedVisibilityScope provides animatedVisibilityScope
                        ) {
                            RestaurantListScreen(
                                onOpenRestaurant = { id -> navController.navigate(detailRoute(id)) }
                            )
                        }
                    }
                    composable(TopLevelDestination.FAVORITES.route) {
                        FavoritesScreen(
                            onOpenRestaurant = { id -> navController.navigate(detailRoute(id)) }
                        )
                    }
                    composable(TopLevelDestination.ROULETTE.route) {
                        RouletteScreen(
                            onOpenRestaurant = { id -> navController.navigate(detailRoute(id)) }
                        )
                    }
                    composable(TopLevelDestination.SETTINGS.route) {
                        SettingsScreen()
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
}
