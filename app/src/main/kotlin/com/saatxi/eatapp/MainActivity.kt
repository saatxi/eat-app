package com.saatxi.eatapp

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import com.saatxi.eatapp.data.prefs.UserPreferences
import com.saatxi.eatapp.navigation.EatAppNavHost
import com.saatxi.eatapp.ui.theme.EatAppTheme
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

// AppCompatDelegate.setApplicationLocales() (see AppLocaleManager) is a silent
// no-op unless the Activity hosting the Compose UI extends AppCompatActivity —
// on API 33+ it still needs an active AppCompatDelegate to look up a Context,
// which only a ComponentActivity subclassing AppCompatActivity creates. Compose,
// enableEdgeToEdge() and the splash screen all work the same either way, since
// AppCompatActivity is itself a ComponentActivity.
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)

        // Null until DataStore's first emission arrives. The splash stays on
        // screen until then instead of blocking onCreate with runBlocking,
        // which would show the default palette for a frame and would also
        // ruin the cold-start metric Phase 7 measures.
        var preferences by mutableStateOf<UserPreferences?>(null)
        splashScreen.setKeepOnScreenCondition { preferences == null }

        (application as EatApplication).userPreferences.preferences
            .onEach { preferences = it }
            .launchIn(lifecycleScope)

        enableEdgeToEdge()
        setContent {
            val currentPreferences = preferences ?: UserPreferences.Defaults
            EatAppTheme(palette = currentPreferences.palette, themeMode = currentPreferences.themeMode) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    EatAppNavHost()
                }
            }
        }
    }
}
