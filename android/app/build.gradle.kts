plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.face_absensi"
    compileSdk = 36 // Sesuai permintaan library camera & image_picker terbaru

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.face_absensi"
        minSdk = 26
        targetSdk = 36

        val flutterVersionCode = project.findProperty("flutter.versionCode") as String? ?: "1"
        val flutterVersionName = project.findProperty("flutter.versionName") as String? ?: "1.0"

        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// FIX: Syntax Kotlin DSL yang benar untuk memaksa namespace pada sub-proyek
subprojects {
    afterEvaluate {
        val p = this
        if (p.hasProperty("android")) {
            val androidExtensions = p.extensions.findByName("android")
            if (androidExtensions is com.android.build.gradle.BaseExtension) {
                if (androidExtensions.namespace == null) {
                    androidExtensions.namespace = p.group.toString()
                }
            }
        }
    }
}