plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.notonote.noto_note"
    // flutter_local_notifications 23 与 androidx.core 1.19 要求 compileSdk >= 37。
    // compileSdk 只影响编译期 API 可用范围，targetSdk 仍沿用 Flutter 模板值。
    compileSdk = 37
    // 纯 Dart 应用不需要 NDK：模板默认的 ndkVersion = flutter.ndkVersion 会让
    // AGP 去下载 28.2.13676358（约 1.4 GB），这里刻意删掉以节省空间。

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 用到 java.time 等 API，Android 12 以下
        // 需要 desugar 才能跑；不开会在运行到 zonedSchedule 时崩。
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.notonote.noto_note"
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
    // 与 isCoreLibraryDesugaringEnabled 配套。2.1.x 起才支持 AGP 8+，
    // 这里跟着官方文档用 2.1.4。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
