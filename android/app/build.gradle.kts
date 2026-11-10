import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.magray.orchards"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.magray.orchards"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val storeFilePath = requireNotNull(keystoreProperties.getProperty("storeFile")) {
                    "storeFile is missing in android/key.properties"
                }
                keyAlias = requireNotNull(keystoreProperties.getProperty("keyAlias")) {
                    "keyAlias is missing in android/key.properties"
                }
                keyPassword = requireNotNull(keystoreProperties.getProperty("keyPassword")) {
                    "keyPassword is missing in android/key.properties"
                }
                storePassword = requireNotNull(keystoreProperties.getProperty("storePassword")) {
                    "storePassword is missing in android/key.properties"
                }
                storeFile = file(storeFilePath)
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }) {
                throw org.gradle.api.GradleException(
                    "Missing android/key.properties. Configure release signing before building a release."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
