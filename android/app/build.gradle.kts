plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val keyProps = Properties()
val keyPropsFile = rootProject.file("key.properties")
if (keyPropsFile.exists()) {
    keyPropsFile.inputStream().use { keyProps.load(it) }
}

android {
    namespace = "su.skrinvex.skryvex"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        @Suppress("DEPRECATION")
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProps["keyAlias"] as String? ?: "sgstudio"
            keyPassword = keyProps["keyPassword"] as String? ?: ""
            storeFile = file(keyProps["storeFile"] as String? ?: "/home/komari/SG.keystore")
            storePassword = keyProps["storePassword"] as String? ?: ""
        }
    }

    defaultConfig {
        applicationId = "su.skrinvex.skryvex"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
