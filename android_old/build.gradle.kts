plugins {
    
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // 👇 THIS LINE LINKS YOUR NEW google-services.json
    id("com.google.gms.google-services")
}

android {
    // 👇 UPDATE THIS TO YOUR NEW NAME
    namespace = "com.butterhearts.app"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        // 👇 UPDATE THIS TO YOUR NEW NAME
        applicationId = "com.butterhearts.app"
        minSdk = 21 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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