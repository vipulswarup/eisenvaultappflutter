plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.eisenvault.eisenvaultappflutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"  // Using the installed NDK version
    //ndkVersion = flutter.ndkVersion

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
        vectorDrawables.useSupportLibrary = true
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    lint {
        disable += "InvalidPackage"
        checkReleaseBuilds = false
    }

    buildFeatures {
        buildConfig = true
    }
}

flutter {
    source = "../.."
}

configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.8.0")
        force("androidx.core:core-ktx:1.8.0")
        force("androidx.appcompat:appcompat:1.4.1")
        force("com.google.android.material:material:1.5.0")
        force("androidx.lifecycle:lifecycle-runtime:2.3.1")
        force("androidx.lifecycle:lifecycle-common:2.3.1")
        force("androidx.lifecycle:lifecycle-viewmodel:2.3.1")
        force("androidx.lifecycle:lifecycle-livedata:2.3.1")
        force("androidx.lifecycle:lifecycle-process:2.3.1")
        force("androidx.lifecycle:lifecycle-service:2.3.1")
        force("androidx.lifecycle:lifecycle-runtime-ktx:2.3.1")
        force("androidx.fragment:fragment:1.3.6")
        force("androidx.activity:activity:1.3.1")
    }
}

dependencies {
    constraints {
        implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.7.10")
        implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.7.10")
    }

    implementation("androidx.core:core:1.8.0")
    implementation("androidx.core:core-ktx:1.8.0")
    implementation("androidx.appcompat:appcompat:1.4.1")
    implementation("com.google.android.material:material:1.5.0")
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
    implementation("androidx.activity:activity:1.3.1")
    implementation("androidx.fragment:fragment:1.3.6")
    implementation("androidx.lifecycle:lifecycle-common:2.3.1")
    implementation("androidx.lifecycle:lifecycle-runtime:2.3.1")
    implementation("androidx.lifecycle:lifecycle-viewmodel:2.3.1")
    implementation("androidx.lifecycle:lifecycle-livedata:2.3.1")
    implementation("androidx.lifecycle:lifecycle-process:2.3.1")
    implementation("androidx.lifecycle:lifecycle-service:2.3.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.3.1")
    implementation("androidx.emoji2:emoji2:1.0.0")
    implementation("androidx.emoji2:emoji2-views:1.0.0")
    implementation("androidx.startup:startup-runtime:1.1.1")
    implementation("androidx.annotation:annotation:1.3.0")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.constraintlayout:constraintlayout:2.1.3")
}