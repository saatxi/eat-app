package com.albertferran.eatapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.albertferran.eatapp.navigation.EatAppNavHost
import com.albertferran.eatapp.ui.theme.EatAppTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            EatAppTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    EatAppNavHost()
                }
            }
        }
    }
}
