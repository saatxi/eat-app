package com.saatxi.eatapp.navigation

import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionLayout
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.RestaurantMenu
import androidx.compose.material3.Icon
import androidx.compose.material3.adaptive.ExperimentalMaterial3AdaptiveApi
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfoV2
import androidx.compose.material3.adaptive.layout.AnimatedPane
import androidx.compose.material3.adaptive.layout.ListDetailPaneScaffoldRole
import androidx.compose.material3.adaptive.navigation.NavigableListDetailPaneScaffold
import androidx.compose.material3.adaptive.navigation.rememberListDetailPaneScaffoldNavigator
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffoldDefaults
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteType
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import android.net.Uri
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
import androidx.window.core.layout.WindowSizeClass
import com.saatxi.eatapp.R
import com.saatxi.eatapp.ui.common.LocalNavAnimatedVisibilityScope
import com.saatxi.eatapp.ui.common.LocalSharedTransitionScope
import com.saatxi.eatapp.ui.common.SCREEN_TRANSITION_DURATION_MS
import com.saatxi.eatapp.ui.detail.RestaurantDetailScreen
import com.saatxi.eatapp.ui.edit.RestaurantEditScreen
import com.saatxi.eatapp.ui.favorites.FavoritesScreen
import com.saatxi.eatapp.ui.help.HelpScreen
import com.saatxi.eatapp.ui.importing.RestaurantImportScreen
import com.saatxi.eatapp.ui.list.EmptyState
import com.saatxi.eatapp.ui.logvisit.LogVisitScreen
import com.saatxi.eatapp.ui.list.RestaurantListScreen
import com.saatxi.eatapp.ui.roulette.RouletteScreen
import com.saatxi.eatapp.ui.settings.SettingsScreen
import com.saatxi.eatapp.ui.stats.StatisticsScreen
import kotlinx.coroutines.launch

private const val ARG_RESTAURANT_ID = "restaurantId"
private const val ARG_URI = "uri"
private const val ARG_LINK_URL = "linkUrl"

private object Routes {
    const val DETAIL = "detail/{restaurantId}"
    const val ADD = "add"
    const val EDIT = "edit/{restaurantId}"
    const val IMPORT = "import/{uri}"
    const val IMPORT_LINK = "import-link/{linkUrl}"
    const val STATS = "stats"
    const val HELP = "help"
    const val LOG_VISIT = "detail/{restaurantId}/log-visit"
}

private fun detailRoute(restaurantId: String) = "detail/$restaurantId"
private fun editRoute(restaurantId: String) = "edit/$restaurantId"
private fun importRoute(uri: Uri) = "import/${Uri.encode(uri.toString())}"
private fun importLinkRoute(url: String) = "import-link/${Uri.encode(url)}"
private fun logVisitRoute(restaurantId: String) = "detail/$restaurantId/log-visit"

private fun NavDestination?.isTopLevelDestinationInHierarchy(destination: TopLevelDestination): Boolean =
    this?.hierarchy?.any { it.route == destination.route } == true

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun EatAppNavHost(
    navController: NavHostController = rememberNavController(),
    // Non-null only on the cold start that opened the app via "Open with
    // EatApp" on a shared restaurant file, rather than the launcher icon.
    startImportUri: Uri? = null,
    // Non-null only on the cold start that opened the app by tapping a
    // restaurant on the home-screen widget (F-68).
    startRestaurantId: String? = null,
    // Non-null only on the cold start that opened the app via the system
    // share sheet with a shared link (e.g. "Share" on a Google Maps place).
    startImportLinkUrl: String? = null
) {
    LaunchedEffect(startImportUri) {
        startImportUri?.let { navController.navigate(importRoute(it)) }
    }
    LaunchedEffect(startRestaurantId) {
        startRestaurantId?.let { navController.navigate(detailRoute(it)) }
    }
    LaunchedEffect(startImportLinkUrl) {
        startImportLinkUrl?.let { navController.navigate(importLinkRoute(it)) }
    }

    val currentDestination = navController.currentBackStackEntryAsState().value?.destination
    // The bottom bar / rail has nowhere to live on the detail, add, edit or
    // import screens — none of them has a tab of its own, they're reached by
    // tapping into one of the other four (or, for import, from outside the app).
    val isFullScreenRoute = currentDestination?.route in
        setOf(
            Routes.DETAIL, Routes.ADD, Routes.EDIT, Routes.IMPORT, Routes.IMPORT_LINK,
            Routes.STATS, Routes.HELP, Routes.LOG_VISIT
        )

    // Below this width, List/Favorites/Roulette keep pushing the full-screen
    // detail/{id} route exactly as before — shared-element transition, hidden
    // nav rail, the works. At/above it, they host the detail pane alongside
    // the list instead of navigating to it, via ListDetailPaneHost below.
    val useListDetailPanes = currentWindowAdaptiveInfoV2().windowSizeClass
        .isWidthAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_MEDIUM_LOWER_BOUND)

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
                layoutType = if (isFullScreenRoute) {
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
                            if (useListDetailPanes) {
                                ListDetailPaneHost(
                                    onEditRestaurant = { id -> navController.navigate(editRoute(id)) },
                                    onLogVisit = { id -> navController.navigate(logVisitRoute(id)) }
                                ) { onOpenRestaurant ->
                                    RestaurantListScreen(
                                        onOpenRestaurant = onOpenRestaurant,
                                        onAddRestaurant = { navController.navigate(Routes.ADD) }
                                    )
                                }
                            } else {
                                RestaurantListScreen(
                                    onOpenRestaurant = { id -> navController.navigate(detailRoute(id)) },
                                    onAddRestaurant = { navController.navigate(Routes.ADD) }
                                )
                            }
                        }
                    }
                    composable(TopLevelDestination.FAVORITES.route) {
                        if (useListDetailPanes) {
                            ListDetailPaneHost(
                                onEditRestaurant = { id -> navController.navigate(editRoute(id)) },
                                onLogVisit = { id -> navController.navigate(logVisitRoute(id)) }
                            ) { onOpenRestaurant ->
                                FavoritesScreen(onOpenRestaurant = onOpenRestaurant)
                            }
                        } else {
                            FavoritesScreen(
                                onOpenRestaurant = { id -> navController.navigate(detailRoute(id)) }
                            )
                        }
                    }
                    composable(TopLevelDestination.ROULETTE.route) {
                        if (useListDetailPanes) {
                            ListDetailPaneHost(
                                onEditRestaurant = { id -> navController.navigate(editRoute(id)) },
                                onLogVisit = { id -> navController.navigate(logVisitRoute(id)) }
                            ) { onOpenRestaurant ->
                                RouletteScreen(onOpenRestaurant = onOpenRestaurant)
                            }
                        } else {
                            RouletteScreen(
                                onOpenRestaurant = { id -> navController.navigate(detailRoute(id)) }
                            )
                        }
                    }
                    composable(TopLevelDestination.SETTINGS.route) {
                        SettingsScreen(
                            onOpenStatistics = { navController.navigate(Routes.STATS) },
                            onOpenHelp = { navController.navigate(Routes.HELP) }
                        )
                    }
                    composable(Routes.STATS) {
                        StatisticsScreen(onBack = { navController.popBackStack() })
                    }
                    composable(Routes.HELP) {
                        HelpScreen(onBack = { navController.popBackStack() })
                    }
                    composable(
                        route = Routes.DETAIL,
                        arguments = listOf(navArgument(ARG_RESTAURANT_ID) { type = NavType.StringType })
                    ) {
                        val animatedVisibilityScope = this
                        CompositionLocalProvider(
                            LocalNavAnimatedVisibilityScope provides animatedVisibilityScope
                        ) {
                            RestaurantDetailScreen(
                                onBack = { navController.popBackStack() },
                                onEditRestaurant = { id -> navController.navigate(editRoute(id)) },
                                onLogVisit = { id -> navController.navigate(logVisitRoute(id)) }
                            )
                        }
                    }
                    composable(
                        route = Routes.LOG_VISIT,
                        arguments = listOf(navArgument(ARG_RESTAURANT_ID) { type = NavType.StringType })
                    ) {
                        LogVisitScreen(onDone = { navController.popBackStack() })
                    }
                    composable(Routes.ADD) {
                        RestaurantEditScreen(
                            onBack = { navController.popBackStack() },
                            restaurantId = null
                        )
                    }
                    composable(
                        route = Routes.EDIT,
                        arguments = listOf(navArgument(ARG_RESTAURANT_ID) { type = NavType.StringType })
                    ) { backStackEntry ->
                        RestaurantEditScreen(
                            onBack = { navController.popBackStack() },
                            restaurantId = backStackEntry.arguments?.getString(ARG_RESTAURANT_ID)
                        )
                    }
                    composable(
                        route = Routes.IMPORT,
                        arguments = listOf(navArgument(ARG_URI) { type = NavType.StringType })
                    ) { backStackEntry ->
                        val uri = backStackEntry.arguments?.getString(ARG_URI)?.let { Uri.parse(Uri.decode(it)) }
                        if (uri != null) {
                            RestaurantImportScreen(
                                uri = uri,
                                onDone = { navController.popBackStack() }
                            )
                        }
                    }
                    composable(
                        route = Routes.IMPORT_LINK,
                        arguments = listOf(navArgument(ARG_LINK_URL) { type = NavType.StringType })
                    ) {
                        // The shared link itself reaches RestaurantEditViewModel through its
                        // SavedStateHandle (this destination's nav argument), not as a parameter
                        // here — same as restaurantId does for Routes.EDIT above.
                        RestaurantEditScreen(
                            onBack = { navController.popBackStack() },
                            restaurantId = null
                        )
                    }
                }
            }
        }
    }
}

/**
 * Hosts a list screen and [RestaurantDetailScreen] side by side (or, below
 * [WindowSizeClass.WIDTH_DP_MEDIUM_LOWER_BOUND], one at a time) instead of
 * pushing a nav-graph route for the detail screen. [listContent] is one of
 * RestaurantListScreen/FavoritesScreen/RouletteScreen, wired to call the
 * `onOpenRestaurant` it's handed instead of the NavHostController.
 *
 * The selected restaurant lives in [navigator], not in a ViewModel: it's the
 * pane equivalent of the `detail/{id}` nav-graph argument, not app state.
 */
@OptIn(ExperimentalMaterial3AdaptiveApi::class)
@Composable
private fun ListDetailPaneHost(
    onEditRestaurant: (String) -> Unit,
    onLogVisit: (String) -> Unit,
    listContent: @Composable (onOpenRestaurant: (String) -> Unit) -> Unit
) {
    val navigator = rememberListDetailPaneScaffoldNavigator<String>()
    val scope = rememberCoroutineScope()

    NavigableListDetailPaneScaffold(
        navigator = navigator,
        listPane = {
            AnimatedPane {
                listContent { id ->
                    scope.launch { navigator.navigateTo(ListDetailPaneScaffoldRole.Detail, id) }
                }
            }
        },
        detailPane = {
            AnimatedPane {
                val selectedId = navigator.currentDestination?.contentKey
                if (selectedId != null) {
                    key(selectedId) {
                        RestaurantDetailScreen(
                            restaurantId = selectedId,
                            onBack = { scope.launch { navigator.navigateBack() } },
                            onEditRestaurant = onEditRestaurant,
                            onLogVisit = onLogVisit
                        )
                    }
                } else {
                    EmptyState(
                        icon = Icons.Outlined.RestaurantMenu,
                        title = stringResource(R.string.detail_placeholder_title),
                        body = stringResource(R.string.detail_placeholder_body),
                        modifier = Modifier.fillMaxSize()
                    )
                }
            }
        }
    )
}
