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
    compileSdk = 36
    ndkVersion = "28.2.13676358"

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
        targetSdk = 35 // Android 15
        versionCode = 120
        versionName = "1.2.0"
        externalNativeBuild {
            cmake {
                arguments("-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON")
            }
        }
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

    packaging {
        jniLibs {
            useLegacyPackaging = false
            // Exclude Google ML Kit libraries that don't support 16KB page sizes
            excludes += listOf(
                "**/libimage_processing_util_jni.so",
                "**/libbarhopper_v3.so",
                "**/libmlkit_google_ocr_pipeline.so"
            )
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
