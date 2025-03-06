plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.eisenvault.eisenvaultappflutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.eisenvault.eisenvaultappflutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Add this enhanced configurations block for resolutionStrategy
configurations.all {
    resolutionStrategy {
        // Force compatible versions of core libraries
        force("androidx.core:core:1.9.0")
        force("androidx.core:core-ktx:1.9.0")
        force("androidx.window:window:1.0.0")
        force("androidx.window:window-java:1.0.0")
        force("androidx.activity:activity:1.6.0")
        force("androidx.fragment:fragment:1.5.5")
        
        // Critical for your error - Lifecycle components
        force("androidx.lifecycle:lifecycle-common:2.5.1")
        force("androidx.lifecycle:lifecycle-runtime:2.5.1")
        force("androidx.lifecycle:lifecycle-viewmodel:2.5.1")
        force("androidx.lifecycle:lifecycle-livedata:2.5.1")
        force("androidx.lifecycle:lifecycle-process:2.5.1")
        
        // Emoji and startup components (mentioned in your error)
        force("androidx.emoji2:emoji2:1.2.0")
        force("androidx.emoji2:emoji2-views:1.2.0")
        force("androidx.startup:startup-runtime:1.1.1")
        
        force("androidx.annotation:annotation:1.5.0")
    }
}