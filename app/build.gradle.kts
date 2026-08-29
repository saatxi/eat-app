import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.androidx.baselineprofile)
}

// --- Git-tag-based versioning ---------------------------------------------
// versionName: derived from the nearest tag.
//   - Exactly on tag "v1.2.0"        -> "1.2.0"
//   - 3 commits past "v1.2.0"        -> "1.2.0-3-g559a7d4"
//   - No tags reachable yet          -> short SHA (--always's own fallback)
//   - git unavailable / not a repo   -> "0.0.0"
// versionCode: total commit count on HEAD. Chosen over a tag-derived number because
// commit count is guaranteed monotonically non-decreasing across every future commit,
// which is what the Play Store requires for versionCode. A tag-derived scheme (e.g.
// "1.2.0" -> 1_002_000) would NOT increase between commits on the same tag, and could
// go backwards/collide across branches or out-of-order hotfix tags.
// NOTE: if CI is added later, the checkout MUST use fetch-depth: 0 and
// fetch-tags: true, or this will silently fall back to versionCode=1 / a bare SHA.
fun runGitCommand(vararg args: String): String? = try {
    val process = ProcessBuilder(listOf("git") + args)
        .directory(rootDir)
        .redirectErrorStream(false)
        .start()
    val output = process.inputStream.bufferedReader().readText().trim()
    if (process.waitFor() == 0 && output.isNotEmpty()) output else null
} catch (e: Exception) {
    null
}

val gitVersionName: String = runGitCommand("describe", "--tags", "--always", "--dirty")
    ?.removePrefix("v")
    ?: "0.0.0"

val gitVersionCode: Int = runGitCommand("rev-list", "--count", "HEAD")
    ?.toIntOrNull()
    ?: 1

val gitCommitShort: String = runGitCommand("rev-parse", "--short", "HEAD") ?: "unknown"
// ---------------------------------------------------------------------------

// --- Local build-time configuration ----------------------------------------
// Values a developer (or CI) can set without touching source: local.properties is
// gitignored, and the matching environment variable is what CI uses instead.
val localProperties = Properties().apply {
    rootProject.file("local.properties")
        .takeIf { it.exists() }
        ?.inputStream()
        ?.use { load(it) }
}

fun localOrEnv(propertyKey: String, envKey: String): String? =
    (localProperties.getProperty(propertyKey) ?: System.getenv(envKey))?.takeIf { it.isNotBlank() }
// ---------------------------------------------------------------------------

// --- Release signing -------------------------------------------------------
// The keystore itself is never committed. When nothing is configured the release
// build still runs, but stays unsigned and says so loudly at build time instead
// of producing an artifact that silently cannot be installed or uploaded.

// A relative path resolves against the repository root; an absolute one is used as is.
val releaseKeystoreFile = localOrEnv("eatapp.keystore.file", "EATAPP_KEYSTORE_FILE")
    ?.let { rootProject.file(it) }
val releaseKeystorePassword = localOrEnv("eatapp.keystore.password", "EATAPP_KEYSTORE_PASSWORD")
val releaseKeyAlias = localOrEnv("eatapp.key.alias", "EATAPP_KEY_ALIAS")
val releaseKeyPassword = localOrEnv("eatapp.key.password", "EATAPP_KEY_PASSWORD")

val hasReleaseSigning = releaseKeystoreFile?.exists() == true &&
    releaseKeystorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null
// ---------------------------------------------------------------------------

// --- Remote database URL ---------------------------------------------------
// Release is always the public raw GitHub URL, hardcoded here. Debug builds can be
// pointed at a branch or a fork through eatapp.database.url in local.properties or
// the EATAPP_DATABASE_URL environment variable, so testing against other data does
// not need a source edit and a rebuild of the release value.
val releaseDatabaseUrl = "https://raw.githubusercontent.com/saatxi/eat-app/main/data/eatapp.db"

val debugDatabaseUrl = localOrEnv("eatapp.database.url", "EATAPP_DATABASE_URL")
    ?.also {
        // The app declares no cleartext traffic permission, so anything but HTTPS
        // would only fail at runtime with a confusing network error.
        require(it.startsWith("https://")) {
            "eatapp.database.url / EATAPP_DATABASE_URL must be an https:// URL, got: $it"
        }
    }
    ?: releaseDatabaseUrl

// The value is pasted into generated Java source, so it has to survive being a
// string literal there.
fun String.asJavaStringLiteral(): String =
    "\"" + replace("\\", "\\\\").replace("\"", "\\\"") + "\""
// ---------------------------------------------------------------------------

android {
    namespace = "com.saatxi.eatapp"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.saatxi.eatapp"
        minSdk = 26
        targetSdk = 36
        versionCode = gitVersionCode
        versionName = gitVersionName
        buildConfigField("String", "GIT_COMMIT", "\"$gitCommitShort\"")
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            buildConfigField("String", "DATABASE_URL", debugDatabaseUrl.asJavaStringLiteral())
        }
        release {
            buildConfigField("String", "DATABASE_URL", releaseDatabaseUrl.asJavaStringLiteral())
            // R8 code shrinking, obfuscation and resource shrinking, enabled only for
            // release builds so debug stays fast and debuggable. This is the AGP 9.3+
            // `optimization {}` DSL, which replaces isMinifyEnabled / isShrinkResources /
            // proguardFiles: it turns on code and resource optimization together and
            // already includes the platform defaults equivalent to
            // "proguard-android-optimize.txt". Project keep rules live in
            // src/main/keepRules/*.keep.
            // https://developer.android.com/topic/performance/app-optimization/enable-app-optimization
            optimization {
                enable = true
            }
            // Play Console wants this to symbolicate native crashes/ANRs. The app has
            // no C/C++ of its own, but dependencies can still ship prebuilt .so files,
            // so this stays on rather than depending on today's dependency set. FULL
            // (not SYMBOL_TABLE) keeps inlined-frame info; bundleRelease writes the
            // result to app/build/outputs/native-debug-symbols/release/.
            ndk {
                debugSymbolLevel = "FULL"
            }
            // Null when no keystore is configured, which leaves the build unsigned.
            signingConfig = signingConfigs.findByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    testOptions {
        unitTests {
            // Robolectric needs the merged resources and manifest to bring up a
            // real Android runtime inside the JVM test task.
            isIncludeAndroidResources = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

// Compose compiler stability/skippability reports, opt-in only: they're one .txt/.csv
// per module dumped into build/, not something every dev needs on every build.
// Usage: gradlew.bat assembleDebug -Peatapp.composeMetrics=true, then inspect
// build/compose_metrics/*-composables.txt (skippable/restartable per composable) and
// *-classes.txt (stable/unstable per class, e.g. RestaurantUiModel).
if (project.findProperty("eatapp.composeMetrics") == "true") {
    composeCompiler {
        val metricsDir = layout.buildDirectory.dir("compose_metrics")
        metricsDestination.set(metricsDir)
        reportsDestination.set(metricsDir)
    }
}

// Surface a missing keystore at build time rather than at install time, and only
// when a release build is actually being run so debug builds stay quiet.
gradle.taskGraph.whenReady {
    if (!hasReleaseSigning && allTasks.any { it.name.contains("Release") }) {
        val keystore = releaseKeystoreFile
        val reason = if (keystore != null && !keystore.exists()) {
            "the configured keystore was not found at ${keystore.absolutePath}"
        } else {
            "release signing is not configured"
        }
        logger.warn(
            "WARNING: $reason, so this release build will be UNSIGNED and cannot be " +
                "installed or uploaded. Set eatapp.keystore.file, eatapp.keystore.password, " +
                "eatapp.key.alias and eatapp.key.password in local.properties, or the matching " +
                "EATAPP_KEYSTORE_FILE, EATAPP_KEYSTORE_PASSWORD, EATAPP_KEY_ALIAS and " +
                "EATAPP_KEY_PASSWORD environment variables. See the README section on signing releases."
        )
    }
}

tasks.register("printVersionInfo") {
    doLast {
        println("versionName=$gitVersionName")
        println("versionCode=$gitVersionCode")
        println("gitCommit=$gitCommitShort")
    }
}


dependencies {
    implementation(libs.androidx.core.ktx)
    // AppCompatDelegate.setApplicationLocales is the only cross-version (API 26+,
    // this app's minSdk) way to change the app's language at runtime; the
    // framework's own per-app LocaleManager only exists from API 33. With
    // Compose it only takes effect if the hosting Activity extends
    // AppCompatActivity (see MainActivity) — without it, the call is a silent
    // no-op even on API 33+, since it still needs an active AppCompatDelegate
    // to look up a Context.
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.animation)
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material3.adaptive.navigation.suite)
    implementation(libs.androidx.material.icons.extended)
    implementation(libs.androidx.graphics.shapes)
    debugImplementation(libs.androidx.ui.tooling)

    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.core.splashscreen)

    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    implementation(libs.androidx.datastore.preferences)
    implementation(libs.kotlinx.coroutines.android)

    // Reads app/src/main/baseline-prof.txt (once generated) at install time and
    // hands it to ART, so a release install gets AOT-compiled hot paths without
    // waiting for on-device profiling to warm up first.
    implementation(libs.androidx.profileinstaller)
    // Regenerated on demand against a connected device/emulator (API 28+) with
    // gradlew.bat :app:generateBaselineProfile — not part of every build.
    baselineProfile(project(":baselineprofile"))

    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.kotlinx.coroutines.test)
}
