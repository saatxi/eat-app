package com.albertferran.eatapp.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.albertferran.eatapp.ui.detail.RestaurantDetailScreen
import com.albertferran.eatapp.ui.list.RestaurantListScreen

private const val ARG_RESTAURANT_ID = "restaurantId"

private object Routes {
    const val LIST = "list"
    const val DETAIL = "detail/{restaurantId}"
}

private fun detailRoute(restaurantId: Long) = "detail/$restaurantId"

@Composable
fun EatAppNavHost(navController: NavHostController = rememberNavController()) {
    NavHost(navController = navController, startDestination = Routes.LIST) {
        composable(Routes.LIST) {
            RestaurantListScreen(
                onOpenRestaurant = { id -> navController.navigate(detailRoute(id)) }
            )
        }
        composable(
            route = Routes.DETAIL,
            arguments = listOf(navArgument(ARG_RESTAURANT_ID) { type = NavType.LongType })
        ) {
            RestaurantDetailScreen(
                onBack = { navController.popBackStack() }
            )
        }
    }
}
