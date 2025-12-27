plugins {
    id("com.android.application")
    id("kotlin-android")
    // El plugin de Flutter debe ir después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // Plugin de Google Services para Firebase
    id("com.google.gms.google-services")
}

// --- ZONA CORREGIDA (Traducción a Kotlin) ---
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// --------------------------------------------

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
        
        // Firebase requiere mínimo API 21 o 23.
        minSdk = flutter.minSdkVersion 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- ZONA FIRMA DIGITAL (Traducción a Kotlin) ---
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            // Asignamos la configuración creada arriba
            signingConfig = signingConfigs.getByName("release")
            
            // Opciones de optimización (por ahora desactivadas para evitar errores)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 1. Plataforma Firebase (Controla las versiones automáticamente)
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))

    // 2. Librería de Autenticación
    implementation("com.google.firebase:firebase-auth")
}