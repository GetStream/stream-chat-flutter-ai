group = "io.getstream.stream_chat_flutter_ai_ondevice"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

// AGP 9 (Flutter 3.44 and later) compiles Kotlin itself, and Flutter warns about plugins that apply
// the Kotlin plugin there. Older AGP needs it applied.
if (com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt() < 9) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "io.getstream.stream_chat_flutter_ai_ondevice"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        // ML Kit's GenAI APIs need Android 8.0.
        minSdk = 26
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

// Set on the tasks rather than the `kotlin` extension, which only AGP 9 adds before this script runs.
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
}

dependencies {
    // The same version as stream-chat-android's `stream-chat-android-ai-ondevice`.
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta4")
    // The generated platform channel dispatches `@async` calls on a coroutine.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
}
