package com.albertferran.eatapp.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.albertferran.eatapp.ui.addedit.AddEditRestaurantScreen
import com.albertferran.eatapp.ui.detail.RestaurantDetailScreen
import com.albertferran.eatapp.ui.list.RestaurantListScreen

private const val ARG_RESTAURANT_ID = "restaurantId"
const val NEW_RESTAURANT_ARG = -1L

private object Routes {
    const val LIST = "list"
    const val ADD_EDIT = "addEdit?restaurantId={restaurantId}"
    const val DETAIL = "detail/{restaurantId}"
}

private fun addEditRoute(restaurantId: Long = NEW_RESTAURANT_ARG) = "addEdit?restaurantId=$restaurantId"
private fun detailRoute(restaurantId: Long) = "detail/$restaurantId"

@Composable
fun EatAppNavHost(navController: NavHostController = rememberNavController()) {
    NavHost(navController = navController, startDestination = Routes.LIST) {
        composable(Routes.LIST) {
            RestaurantListScreen(
                onAddRestaurant = { navController.navigate(addEditRoute()) },
                onOpenRestaurant = { id -> navController.navigate(detailRoute(id)) }
            )
        }
        composable(
            route = Routes.ADD_EDIT,
            arguments = listOf(
                navArgument(ARG_RESTAURANT_ID) {
                    type = NavType.LongType
                    defaultValue = NEW_RESTAURANT_ARG
                }
            )
        ) {
            AddEditRestaurantScreen(
                onSaved = { navController.popBackStack() },
                onBack = { navController.popBackStack() }
            )
        }
        composable(
            route = Routes.DETAIL,
            arguments = listOf(navArgument(ARG_RESTAURANT_ID) { type = NavType.LongType })
        ) {
            RestaurantDetailScreen(
                onEdit = { id -> navController.navigate(addEditRoute(id)) },
                onDeleted = { navController.popBackStack() },
                onBack = { navController.popBackStack() }
            )
        }
    }
}
