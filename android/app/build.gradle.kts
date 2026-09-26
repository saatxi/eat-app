import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Git-tag-based versioning ---------------------------------------------
// Kept identical to the scheme the previous (native) Android build used, so
// this Flutter build keeps producing the same, strictly-increasing versionCode
// the Play listing already has:
//   versionName: from the nearest tag ("1.2.0", "1.2.0-3-g559a7d4", or a short
//                SHA before the first tag; "-dirty" when the tree is modified).
//   versionCode: total commit count on HEAD -- guaranteed monotonically
//                non-decreasing, which is what Play requires. pubspec.yaml's
//                build number is intentionally ignored.
// NOTE: a CI checkout MUST use fetch-depth: 0 and fetch-tags: true, or this
// silently falls back to versionCode=1 / a bare SHA.
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
// ---------------------------------------------------------------------------

// --- Release signing -------------------------------------------------------
// Same keystore and passwords as the previous Gradle build: read from the
// repository-root local.properties (shared with the former native module) or
// the matching EATAPP_* environment variables. A relative keystore path is
// resolved against the repository root, exactly as before. When nothing is
// configured the release build still runs, but stays unsigned and says so
// loudly at build time instead of producing an artifact Play silently rejects.
val repoRoot = rootDir.parentFile
val localProperties = Properties().apply {
    repoRoot.resolve("local.properties")
        .takeIf { it.exists() }
        ?.inputStream()
        ?.use { load(it) }
}

fun localOrEnv(propertyKey: String, envKey: String): String? =
    (localProperties.getProperty(propertyKey) ?: System.getenv(envKey))?.takeIf { it.isNotBlank() }

val releaseKeystoreFile = localOrEnv("eatapp.keystore.file", "EATAPP_KEYSTORE_FILE")
    ?.let { repoRoot.resolve(it) }
val releaseKeystorePassword = localOrEnv("eatapp.keystore.password", "EATAPP_KEYSTORE_PASSWORD")
val releaseKeyAlias = localOrEnv("eatapp.key.alias", "EATAPP_KEY_ALIAS")
val releaseKeyPassword = localOrEnv("eatapp.key.password", "EATAPP_KEY_PASSWORD")

val hasReleaseSigning = releaseKeystoreFile?.exists() == true &&
    releaseKeystorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null
// ---------------------------------------------------------------------------

android {
    namespace = "com.saatxi.eatapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.saatxi.eatapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = gitVersionCode
        versionName = gitVersionName

        // Flutter's plugin fills defaultConfig's abiFilters with the three ABIs
        // it builds (armeabi-v7a, arm64-v8a, x86_64) -- see
        // FlutterPlugin.configureAbiWithoutSplits. A Play-distributed app never
        // ships to x86_64, so it is dropped here to trim the bundle. Setting it
        // in defaultConfig (the point Flutter documents as taking precedence
        // over its own defaults) is what makes the narrowing actually stick.
        ndk {
            abiFilters.clear()
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
        }
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
        // Re-add x86_64 for debug only, so `flutter run` on an x86_64 emulator
        // still works. The release build type sets no abiFilters of its own, so
        // it inherits the arm-only defaultConfig above and the shipped bundle
        // stays lean.
        debug {
            ndk {
                abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a", "x86_64"))
            }
        }
        release {
            // Null when no keystore is configured, which leaves the bundle
            // unsigned so scripts/bundle.ps1 -AllowUnsigned still means what it says.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Surface a missing keystore at build time rather than at upload time, and only
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
            "WARNING: $reason, so this release bundle will be UNSIGNED and cannot be " +
                "uploaded to Play. Set eatapp.keystore.file, eatapp.keystore.password, " +
                "eatapp.key.alias and eatapp.key.password in local.properties, or the matching " +
                "EATAPP_KEYSTORE_FILE, EATAPP_KEYSTORE_PASSWORD, EATAPP_KEY_ALIAS and " +
                "EATAPP_KEY_PASSWORD environment variables. See the README section on signing releases."
        )
    }
}
