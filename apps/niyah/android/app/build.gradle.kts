plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Fixed key for test APKs: CI rebuilds it from the GitHub secrets (see
// .github/workflows/ci.yml). Without it the debug key is used, which differs per
// machine and forces an uninstall before every update.
val niyahKeystore = System.getenv("NIYAH_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }?.let { file(it) }

android {
    namespace = "app.niyah.niyah"
    // flutter_local_notifications needs compileSdk 35+ and core library desugaring.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.niyah.niyah"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (niyahKeystore != null) {
            create("niyah") {
                storeFile = niyahKeystore
                storePassword = System.getenv("NIYAH_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("NIYAH_KEY_ALIAS")
                keyPassword = System.getenv("NIYAH_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // The key never goes in the repository: it only comes from environment variables.
            // Without NIYAH_KEYSTORE_PATH the debug key is used, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName(if (niyahKeystore != null) "niyah" else "debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
