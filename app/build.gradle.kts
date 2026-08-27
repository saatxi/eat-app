import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
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

// --- Release signing -------------------------------------------------------
// Credentials are read from local.properties (gitignored) or, for CI, from
// environment variables. The keystore itself is never committed. When nothing
// is configured the release build still runs, but stays unsigned and says so
// loudly at build time instead of producing an artifact that silently cannot
// be installed or uploaded.
val localProperties = Properties().apply {
    rootProject.file("local.properties")
        .takeIf { it.exists() }
        ?.inputStream()
        ?.use { load(it) }
}

fun signingSecret(propertyKey: String, envKey: String): String? =
    (localProperties.getProperty(propertyKey) ?: System.getenv(envKey))?.takeIf { it.isNotBlank() }

// A relative path resolves against the repository root; an absolute one is used as is.
val releaseKeystoreFile = signingSecret("eatapp.keystore.file", "EATAPP_KEYSTORE_FILE")
    ?.let { rootProject.file(it) }
val releaseKeystorePassword = signingSecret("eatapp.keystore.password", "EATAPP_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingSecret("eatapp.key.alias", "EATAPP_KEY_ALIAS")
val releaseKeyPassword = signingSecret("eatapp.key.password", "EATAPP_KEY_PASSWORD")

val hasReleaseSigning = releaseKeystoreFile?.exists() == true &&
    releaseKeystorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null
// ---------------------------------------------------------------------------

android {
    namespace = "com.albertferran.eatapp"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.albertferran.eatapp"
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
        release {
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
            // Null when no keystore is configured, which leaves the build unsigned.
            signingConfig = signingConfigs.findByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
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
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)
    debugImplementation(libs.androidx.ui.tooling)

    implementation(libs.androidx.navigation.compose)

    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.kotlinx.coroutines.test)
}
