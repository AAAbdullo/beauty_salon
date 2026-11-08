import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.beauty_salons"
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
        // Должен совпадать с ограничением ключа Yandex MapKit в кабинете разработчика.
        applicationId = "com.abdullo.beautySalons"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // Ключ Yandex MapKit не хранится в git: берётся из android/local.properties
        // (YANDEX_MAPKIT_API_KEY=...) или из переменной окружения на CI.
        val localProps = Properties().apply {
            val file = rootProject.file("local.properties")
            if (file.exists()) file.inputStream().use { load(it) }
        }
        val mapkitKey = localProps.getProperty("YANDEX_MAPKIT_API_KEY")
            ?: System.getenv("YANDEX_MAPKIT_API_KEY")
            ?: ""
        buildConfigField("String", "YANDEX_MAPKIT_API_KEY", "\"$mapkitKey\"")
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Нужна приложению напрямую: MainApplication вызывает MapKitFactory.setApiKey.
    // Плагин yandex_mapkit подключает библиотеку как implementation, поэтому снаружи она не видна.
    // Версия и вариант (full) должны совпадать с yandexMapkit.variant в gradle.properties и с версией плагина yandex_mapkit.
    implementation("com.yandex.android:maps.mobile:4.39.1-full")
}
