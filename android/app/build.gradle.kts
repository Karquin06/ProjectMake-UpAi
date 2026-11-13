import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Llave de publicación (H-01): android/key.properties y el .jks NO se suben al
// repositorio (están en .gitignore). Se crean con
//   .\auditoria\scripts\crear_llave_release.ps1
val propiedadesLlave = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) FileInputStream(archivo).use { load(it) }
}
val hayLlaveRelease = !propiedadesLlave.getProperty("storeFile").isNullOrBlank()

android {
    namespace = "com.example.mackeupai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mackeupai"
        // firebase_auth 6.x y google_sign_in 7.x requieren minSdk 23.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Certificado de depuración compartido por el equipo: así todos firman con
    // la misma huella SHA registrada en Firebase (inicio de sesión con Google).
    // Solo firma builds de depuración; el release usa su propia llave.
    signingConfigs {
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (hayLlaveRelease) {
            create("release") {
                storeFile = file(propiedadesLlave.getProperty("storeFile"))
                storePassword = propiedadesLlave.getProperty("storePassword")
                keyAlias = propiedadesLlave.getProperty("keyAlias")
                keyPassword = propiedadesLlave.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Nunca con la llave de depuración: está en el repositorio público.
            if (hayLlaveRelease) signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Sin llave de publicación no se arma un release (antes se firmaba en silencio
// con la llave de depuración).
gradle.taskGraph.whenReady {
    val armaRelease = allTasks.any { it.project == project && it.name.contains("Release") &&
        (it.name.startsWith("assemble") || it.name.startsWith("bundle") || it.name.startsWith("package")) }
    if (armaRelease && !hayLlaveRelease) {
        throw GradleException(
            "Falta android/key.properties con la llave de publicación (H-01). " +
                "Créala con .\\auditoria\\scripts\\crear_llave_release.ps1",
        )
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
