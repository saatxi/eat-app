allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// receive_sharing_intent's Gradle config sets no JVM target for either Java or
// Kotlin. Kotlin then defaults to whatever JDK Gradle itself runs on while AGP
// defaults Java far lower, and the mismatch ("Inconsistent JVM-target
// compatibility") fails the build. Pin both of its halves to 17 — the target
// this app already compiles to — so they cannot drift. Scoped to this one
// plugin so no other plugin's own settings are touched, and done through
// `plugins.withId` (rather than `afterEvaluate`, since these subprojects are
// evaluated eagerly by the block above).
subprojects {
    if (name == "receive_sharing_intent") {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
                )
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
