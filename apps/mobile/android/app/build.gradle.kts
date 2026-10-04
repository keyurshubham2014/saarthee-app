import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (V2 TASK-13 step 14; docs/ops/release-android.md). The upload key lives OUTSIDE the
// repository (~/saarthee-keys/); its location and passwords come from android/key.properties
// (git-ignored) or SAARTHEE_UPLOAD_* environment variables. Never commit either.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

fun signingValue(key: String, env: String): String? =
    (keystoreProperties.getProperty(key) ?: System.getenv(env))?.takeIf { it.isNotBlank() }

val uploadStoreFile = signingValue("storeFile", "SAARTHEE_UPLOAD_STORE_FILE")
val uploadStorePassword = signingValue("storePassword", "SAARTHEE_UPLOAD_STORE_PASSWORD")
val uploadKeyAlias = signingValue("keyAlias", "SAARTHEE_UPLOAD_KEY_ALIAS")
val uploadKeyPassword = signingValue("keyPassword", "SAARTHEE_UPLOAD_KEY_PASSWORD")
val hasUploadKey = listOf(uploadStoreFile, uploadStorePassword, uploadKeyAlias, uploadKeyPassword).all { it != null }

// Escape hatch for local/emulator release builds only: signs with the debug key, which Play rejects.
// Opt in with -Psaarthee.allowDebugSigning=true or SAARTHEE_ALLOW_DEBUG_SIGNING=1.
val allowDebugSigning =
    (project.findProperty("saarthee.allowDebugSigning") as String?) == "true" ||
        System.getenv("SAARTHEE_ALLOW_DEBUG_SIGNING") == "1"

android {
    namespace = "in.saarthee.saarthee"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "in.saarthee.saarthee"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Version from pubspec.yaml (`version: 2.0.0+<n>`); override with --build-number.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = file(uploadStoreFile!!)
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // No silent debug-signing fallback: without the upload key the release build fails
            // (preReleaseBuild check below) unless debug signing was explicitly allowed.
            signingConfig = when {
                hasUploadKey -> signingConfigs.getByName("release")
                allowDebugSigning -> signingConfigs.getByName("debug")
                else -> null
            }
            isDebuggable = false
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        if (!hasUploadKey && !allowDebugSigning) {
            throw GradleException(
                "Release signing is not configured. Create android/key.properties (storeFile, " +
                    "storePassword, keyAlias, keyPassword) pointing at the upload keystore outside the " +
                    "repository, or set SAARTHEE_UPLOAD_* variables. See docs/ops/release-android.md. " +
                    "(Local-only builds: -Psaarthee.allowDebugSigning=true.)",
            )
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
