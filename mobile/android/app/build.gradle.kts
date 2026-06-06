import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun releaseKeystoreConfigured(): Boolean {
    if (keystorePropertiesFile.exists()) {
        return true
    }
    return !System.getenv("CM_KEYSTORE_PATH").isNullOrBlank()
}

android {
    namespace = "com.alanz.gains"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: System.getenv("CM_KEY_ALIAS")
            keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: System.getenv("CM_KEY_PASSWORD")
            storePassword = keystoreProperties.getProperty("storePassword")
                ?: System.getenv("CM_KEYSTORE_PASSWORD")
            val storePath = keystoreProperties.getProperty("storeFile")
                ?: System.getenv("CM_KEYSTORE_PATH")
            if (!storePath.isNullOrBlank()) {
                storeFile = file(storePath)
            }
        }
    }

    defaultConfig {
        applicationId = "com.alanz.gains"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (releaseKeystoreConfigured()) {
                signingConfigs.getByName("release")
            } else {
                // Local `flutter run --release` only — Play Store builds require key.properties or Codemagic signing env.
                signingConfigs.getByName("debug")
            }
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
