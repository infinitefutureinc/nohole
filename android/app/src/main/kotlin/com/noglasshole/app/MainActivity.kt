package com.noglasshole.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.noglasshole.app.ui.NoGlassholeApp
import com.noglasshole.app.ui.theme.NoGlassholeTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            NoGlassholeTheme {
                NoGlassholeApp()
            }
        }
    }
}
