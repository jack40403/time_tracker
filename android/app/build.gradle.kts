import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")

    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile: File = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

val releaseStoreFilePath: String? = keystoreProperties.getProperty("storeFile")
val releaseStoreFile: File? = releaseStoreFilePath?.let { path: String -> file(path) }

fun validateReleaseSigningConfig() {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Release builds require android/key.properties. " +
                "Refusing to create a release APK signed with the debug key because it cannot update the published app."
        )
    }

    val missingProperties = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
        .filter { propertyName -> keystoreProperties.getProperty(propertyName).isNullOrBlank() }

    if (missingProperties.isNotEmpty()) {
        throw GradleException(
            "Release signing config is incomplete in android/key.properties. " +
                "Missing: ${missingProperties.joinToString(", ")}"
        )
    }

    if (releaseStoreFile == null || !releaseStoreFile.exists()) {
        throw GradleException(
            "Release keystore was not found: ${releaseStoreFilePath ?: "(missing storeFile)"}. " +
                "The storeFile path is resolved relative to android/app."
        )
    }
}

fun isReleaseBuildRequested(): Boolean {
    return gradle.startParameter.taskNames.any { taskName ->
        taskName.contains("Release", ignoreCase = true)
    }
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { path: String -> file(path) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }
    
    namespace = "com.example.time_tracker"
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
        applicationId = "com.example.time_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    buildTypes {
        release {
            if (isReleaseBuildRequested()) {
                validateReleaseSigningConfig()
            }
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            
            // 加入 Proguard 規則以防止 Widget 類別被混淆
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    lint {
        checkReleaseBuilds = false
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

project.gradle.startParameter.excludedTaskNames.add("checkReleaseAarMetadata")
project.gradle.startParameter.excludedTaskNames.add("checkDebugAarMetadata")


