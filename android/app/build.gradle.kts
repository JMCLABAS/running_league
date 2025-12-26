plugins {
    id("com.android.application")
    id("kotlin-android")
    // El plugin de Flutter debe ir después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // Plugin de Google Services para Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.running_league"
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
        applicationId = "com.example.running_league"
        
        // --- CAMBIO IMPORTANTE ---
        // Firebase requiere mínimo API 21 o 23. Ponemos 23 para ir seguros.
        minSdk = flutter.minSdkVersion 
        // -------------------------

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Añadir tu propia configuración de firma para release.
            // Por ahora usamos la clave de debug para que funcione "flutter run --release".
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// --- BLOQUE DE DEPENDENCIAS AÑADIDO ---
dependencies {
    // 1. Plataforma Firebase (Controla las versiones automáticamente)
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))

    // 2. Librería de Autenticación
    implementation("com.google.firebase:firebase-auth")
}
