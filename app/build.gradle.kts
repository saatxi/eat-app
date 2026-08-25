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

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
}
