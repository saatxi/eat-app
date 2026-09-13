package com.saatxi.eatapp

import android.content.Intent
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
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.navigation.EatAppNavHost
import com.saatxi.eatapp.ui.theme.EatAppTheme
import com.saatxi.eatapp.widget.EXTRA_RESTAURANT_ID
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

// AppCompatDelegate.setApplicationLocales() (see AppLocaleManager) is a silent
// no-op unless the Activity hosting the Compose UI extends AppCompatActivity —
// on API 33+ it still needs an active AppCompatDelegate to look up a Context,
// which only a ComponentActivity subclassing AppCompatActivity creates. Compose,
// enableEdgeToEdge() and the splash screen all work the same either way, since
// AppCompatActivity is itself a ComponentActivity.
@AndroidEntryPoint
class MainActivity : AppCompatActivity() {

    @Inject
    lateinit var userPreferences: UserPreferencesRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)

        // Null until DataStore's first emission arrives. The splash stays on
        // screen until then instead of blocking onCreate with runBlocking,
        // which would show the default palette for a frame and would also
        // ruin the cold-start metric Phase 7 measures.
        var preferences by mutableStateOf<UserPreferences?>(null)
        splashScreen.setKeepOnScreenCondition { preferences == null }

        userPreferences.preferences
            .onEach { preferences = it }
            .launchIn(lifecycleScope)

        // Non-null only when the app was opened by tapping a shared restaurant
        // file from another app ("Open with EatApp") rather than the launcher.
        val importUri = intent?.takeIf { it.action == Intent.ACTION_VIEW }?.data
        // Non-null only when opened by tapping a restaurant on the home-screen
        // widget (see widget/WantToTryWidget.kt) — an explicit intent naming
        // this activity directly, so it never touches the ACTION_VIEW filters
        // the import flow above uses.
        val startRestaurantId = intent?.getStringExtra(EXTRA_RESTAURANT_ID)
        // Non-null only when opened via the system share sheet (e.g. "Share"
        // on a place in Google Maps) — see MapsLinkResolver.kt.
        val importLinkUrl = intent
            ?.takeIf { it.action == Intent.ACTION_SEND && it.type == "text/plain" }
            ?.getStringExtra(Intent.EXTRA_TEXT)

        enableEdgeToEdge()
        setContent {
            val currentPreferences = preferences ?: UserPreferences.Defaults
            EatAppTheme(palette = currentPreferences.palette, themeMode = currentPreferences.themeMode) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    EatAppNavHost(
                        startImportUri = importUri,
                        startRestaurantId = startRestaurantId,
                        startImportLinkUrl = importLinkUrl
                    )
                }
            }
        }
    }
}
