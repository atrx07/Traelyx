import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Client configuration stays in ignored local state; generated resources stay under build/.
val firebaseClientFile = rootProject.file("../.dart_tool/firebase/google-services.json")
val firebaseClientValues = if (providers.gradleProperty("traelyxFirebaseEnabled").orNull != "false" && firebaseClientFile.isFile) {
    try {
        val root = JsonSlurper().parse(firebaseClientFile) as Map<*, *>
        require(!root.containsKey("private_key") && root["type"] != "service_account") {
            "Only Firebase Android client configuration is accepted"
        }
        val project = root["project_info"] as Map<*, *>
        val client = (root["client"] as List<*>).map { it as Map<*, *> }.single {
            val info = it["client_info"] as Map<*, *>
            (info["android_client_info"] as Map<*, *>)["package_name"] == "io.github.atrx07.traelyx"
        }
        val info = client["client_info"] as Map<*, *>
        val apiKey = ((client["api_key"] as List<*>).first() as Map<*, *>)["current_key"] as String
        val values = mapOf(
            "project_id" to project["project_id"] as String,
            "sender_id" to project["project_number"] as String,
            "app_id" to info["mobilesdk_app_id"] as String,
            "client_key" to apiKey,
        )
        require(values.getValue("project_id").matches(Regex("[a-z][a-z0-9-]{4,62}")))
        require(values.getValue("sender_id").matches(Regex("[0-9]{6,20}")))
        require(values.getValue("app_id").matches(Regex("1:[0-9]+:android:[a-f0-9]+")))
        require(apiKey.matches(Regex("[A-Za-z0-9_-]{39}")))
        values
    } catch (_: Exception) {
        throw GradleException("Invalid Firebase Android client configuration; details redacted")
    }
} else emptyMap()

android {
    buildFeatures { resValues = true }
    namespace = "io.github.atrx07.traelyx"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.atrx07.traelyx"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner =
            "io.github.atrx07.traelyx.recorder.RecorderLifecycleInstrumentation"
        for (field in listOf("project_id", "sender_id", "app_id", "client_key")) {
            resValue("string", "traelyx_firebase_$field", firebaseClientValues[field] ?: "")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    implementation("com.google.firebase:firebase-messaging:25.0.1")
    testImplementation("junit:junit:4.13.2")
}
