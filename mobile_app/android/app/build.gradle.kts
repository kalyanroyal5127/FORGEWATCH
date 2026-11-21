plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kalyan.forgewatch"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    flavorDimensions += "environment"
    productFlavors {
        create("development") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        create("production") {
            dimension = "environment"
            manifestPlaceholders["usesCleartextTraffic"] = "false"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kalyan.forgewatch"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseStorePath = providers.environmentVariable("FORGEWATCH_KEYSTORE_PATH").orNull
    val releaseStorePassword = providers.environmentVariable("FORGEWATCH_KEYSTORE_PASSWORD").orNull
    val releaseKeyAlias = providers.environmentVariable("FORGEWATCH_KEY_ALIAS").orNull
    val releaseKeyPassword = providers.environmentVariable("FORGEWATCH_KEY_PASSWORD").orNull
    val releaseSigningReady = listOf(releaseStorePath, releaseStorePassword, releaseKeyAlias, releaseKeyPassword).all { !it.isNullOrBlank() }
    if (releaseSigningReady) {
        signingConfigs.create("release") {
            storeFile = file(releaseStorePath!!)
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    buildTypes {
        release {
            if (releaseSigningReady) signingConfig = signingConfigs.getByName("release")
        }
    }

    tasks.configureEach {
        if (name.contains("ProductionRelease", ignoreCase = true) && !releaseSigningReady) {
            doFirst { throw GradleException("Set FORGEWATCH_KEYSTORE_PATH, FORGEWATCH_KEYSTORE_PASSWORD, FORGEWATCH_KEY_ALIAS, and FORGEWATCH_KEY_PASSWORD to build a signed production APK.") }
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
