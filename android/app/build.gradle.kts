import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key: environment variables in CI (.github/workflows/release.yml), or
// android/key.properties for local builds (see README.md). Without either, release builds
// are signed with the debug key, which can't update an installed release.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(env: String, property: String): String? =
    providers.environmentVariable(env).orNull?.takeIf { it.isNotEmpty() }
        ?: keystoreProperties.getProperty(property)?.takeIf { it.isNotEmpty() }

android {
    namespace = "com.ruchan.steps"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ruchan.steps"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 8.0+: needed for notification channels / foreground services.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        val releaseStore = signingValue("RELEASE_STORE_FILE", "storeFile")
        if (releaseStore != null) {
            create("release") {
                val password = signingValue("RELEASE_STORE_PASSWORD", "storePassword")
                storeFile = file(releaseStore)
                storePassword = password
                keyAlias = signingValue("RELEASE_KEY_ALIAS", "keyAlias") ?: "upload"
                // keytool's default PKCS12 keystores use one password for the store and the key.
                keyPassword = signingValue("RELEASE_KEY_PASSWORD", "keyPassword") ?: password
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            // Compress the native libraries (the Flutter engine and the compiled Dart code),
            // which are most of the APK: about half the download for each update, for a few
            // more MB of storage once installed, where Android unpacks them.
            useLegacyPackaging = true
        }
    }
}

dependencies {
    // FileProvider, which hands downloaded updates to the system installer (AppUpdates.kt).
    // Same version the Flutter embedding already brings in.
    implementation("androidx.core:core:1.13.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
