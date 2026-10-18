plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chiave fissa per gli APK di prova: la CI la ricostruisce dai segreti di GitHub
// (vedi .github/workflows/ci.yml). Senza, si usa la chiave di debug, che cambia da
// macchina a macchina e costringe a disinstallare l'app prima di ogni aggiornamento.
val niyahKeystore = System.getenv("NIYAH_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }?.let { file(it) }

android {
    namespace = "app.niyah"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Richiesto da flutter_local_notifications (API java.time su Android vecchi).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // ⚠️ Identificativo definitivo da confermare prima della prima pubblicazione
        // su Google Play: dopo non si può più cambiare.
        applicationId = "app.niyah"
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
            // La chiave non va mai nel repository: arriva solo da variabili d'ambiente.
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
