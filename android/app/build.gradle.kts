plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    // NOTE: The kotlin-android plugin used to live here but AGP 9 makes
    // Kotlin support built-in. Re-adding it would error with "the
    // kotlin-android plugin must be removed" on AGP 9.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.project_cmsc23"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications to use java.time on minSdk < 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // AGP 9's built-in Kotlin reads jvmTarget from compileOptions.
    // The kotlinOptions { jvmTarget = ... } block used to live here, but it
    // belonged to the kotlin-android plugin we just removed.

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.project_cmsc23"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // flutter_local_notifications needs multidex when desugaring kicks in
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}