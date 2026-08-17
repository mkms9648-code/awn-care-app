plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Google Services plugin (needed for firebase_core/firebase_messaging)
// hard-fails the build if google-services.json is missing from this module.
// There's no real Firebase project wired up yet (see the
// google-services.json.PLACEHOLDER_NEEDS_REAL_FIREBASE_PROJECT file next to
// this one), so applying it unconditionally would break `flutter build` /
// `flutter run` for every engineer until that file is replaced with a real
// one from the Firebase console. Applying it only when the real file is
// present is the standard guard for this (declared "apply false" in
// settings.gradle.kts, applied imperatively here).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.awncare.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
       
        applicationId = "com.awncare.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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

flutter {
    source = "../.."
}
