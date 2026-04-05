import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. Load the keystore properties from the root 'android' folder
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { input ->
        keystoreProperties.load(input)
    }
    println("SUCCESS: key.properties loaded from ${keystorePropertiesFile.absolutePath}")
} else {
    // If you see this in your terminal, the file is in the wrong folder!
    println("CRITICAL: key.properties NOT FOUND at ${keystorePropertiesFile.absolutePath}")
}

android {
    namespace = "com.butterhearts.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.butterhearts.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val alias = keystoreProperties.getProperty("keyAlias")
            val keyPass = keystoreProperties.getProperty("keyPassword")
            val storePass = keystoreProperties.getProperty("storePassword")
            val stFile = keystoreProperties.getProperty("storeFile")

            // If these are null, the build will skip signing and throw the NullPointerException later
            if (alias != null && keyPass != null && storePass != null && stFile != null) {
                keyAlias = alias
                keyPassword = keyPass
                storePassword = storePass
                // This resolves 'upload-keystore.jks' inside the 'android/app' folder
                storeFile = projectDir.resolve(stFile)
            } else {
                println("STATUS: Signing properties missing. Check your key.properties content.")
            }
        }
    }

    buildTypes {
        release {
            // Tells Gradle to use the 'release' signing config created above
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    applicationVariants.all {
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.ApkVariantOutputImpl
            output.outputFileName = "ButterHeartsCakes.apk"
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}