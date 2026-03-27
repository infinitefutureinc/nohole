package com.noglasshole.app.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

// Electric yellow — matches the iOS NoGlasshole brand accent
val BrandYellow = Color(0xFFFFE600)
val BrandYellowDark = Color(0xFFCCB800)

private val DarkColorScheme = darkColorScheme(
    primary = BrandYellow,
    onPrimary = Color.Black,
    secondary = BrandYellowDark,
    onSecondary = Color.Black,
    background = Color(0xFF0A0A0A),
    surface = Color(0xFF1A1A1A),
    onBackground = Color.White,
    onSurface = Color.White,
)

private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF8B7A00),
    onPrimary = Color.White,
    secondary = Color(0xFFB8A200),
    onSecondary = Color.White,
    background = Color(0xFFFFFBFE),
    surface = Color(0xFFF5F0FF),
    onBackground = Color(0xFF1C1B1F),
    onSurface = Color(0xFF1C1B1F),
)

@Composable
fun NoGlassholeTheme(
    // Default to dark — smart glasses / privacy tool aesthetic
    darkTheme: Boolean = true,
    dynamicColor: Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && darkTheme -> dynamicDarkColorScheme(LocalContext.current)
        dynamicColor && !darkTheme -> dynamicLightColorScheme(LocalContext.current)
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
