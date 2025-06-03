import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.eisenvault.eisenvaultappflutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.eisenvault"
        minSdk = 24 // Android 7.0 (Nougat)
        targetSdk = 34 // Android 14
        versionCode = 6
        versionName = "1.0.4"
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    implementation("com.google.android.play:feature-delivery:2.1.0")
    implementation("com.google.android.play:asset-delivery:2.3.0")
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:review:2.0.2")
    // Removed core-ktx:1.10.3 as it does not exist
    // If you need core-ktx, use the latest valid version like 1.8.1:
    // implementation("com.google.android.play:core-ktx:1.8.1")
}

flutter {
    source = "../.."
}
