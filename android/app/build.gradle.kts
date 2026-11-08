plugins {
    id("com.android.application")
    // Kotlin is applied explicitly so KSP (Room's annotation processor) has a Kotlin compiler
    // to attach to. Order matters: the Flutter Gradle Plugin must come after Android + Kotlin.
    id("org.jetbrains.kotlin.android")
    id("com.google.devtools.ksp")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cyberguard.performance_optimization"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cyberguard.performance_optimization"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 7.0 (API 24) is the module's minimum: everything newer (StorageStatsManager
        // on 26+, thermal status on 29+) degrades to "Unavailable" instead of crashing.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

dependencies {
    // CyberGuard performance module: Room (local database) + WorkManager (periodic sampling).
    // These are the only third-party Android dependencies the module is allowed to use.
    implementation("androidx.room:room-runtime:2.8.5")
    ksp("androidx.room:room-compiler:2.8.5")
    implementation("androidx.work:work-runtime:2.12.0")
}

ksp {
    // Schema export: every schema version is committed to android/app/schemas so future
    // changes can be reviewed and migrated explicitly (no destructive migration).
    arg("room.schemaLocation", "$projectDir/schemas")
}

flutter {
    source = "../.."
}
