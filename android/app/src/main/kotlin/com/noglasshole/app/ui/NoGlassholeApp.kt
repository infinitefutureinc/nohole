package com.noglasshole.app.ui

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.noglasshole.app.ui.home.HomeScreen
import com.noglasshole.app.ui.preview.MediaPreviewScreen
import com.noglasshole.app.ui.settings.SettingsScreen

sealed class Screen(val route: String) {
    data object Home : Screen("home")
    data object Settings : Screen("settings")
    data class Preview(val mediaId: Long) : Screen("preview/$mediaId") {
        companion object {
            const val ROUTE = "preview/{mediaId}"
        }
    }
}

@Composable
fun NoGlassholeApp() {
    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = Screen.Home.route) {
        composable(Screen.Home.route) {
            HomeScreen(
                onNavigateToPreview = { mediaId ->
                    navController.navigate("preview/$mediaId")
                },
                onNavigateToSettings = {
                    navController.navigate(Screen.Settings.route)
                }
            )
        }
        composable(
            route = Screen.Preview.ROUTE,
            arguments = listOf(navArgument("mediaId") { type = NavType.LongType })
        ) { backStackEntry ->
            val mediaId = backStackEntry.arguments?.getLong("mediaId") ?: return@composable
            MediaPreviewScreen(
                mediaId = mediaId,
                onNavigateUp = { navController.navigateUp() }
            )
        }
        composable(Screen.Settings.route) {
            SettingsScreen(onNavigateUp = { navController.navigateUp() })
        }
    }
}
