import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ===== 发布签名配置 =====
// 凭据从 android/key.properties 读取（与 keystore 一起被 .gitignore 排除，绝不入库）。
// 文件不存在时退回 debug 签名，保证 clone 后 `flutter build apk --release` 仍可直接跑通；
// 一旦存在即启用正式签名。生成 keystore / 配置的完整步骤见 docs/release-signing.md。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseSigning = keystorePropertiesFile.exists()

android {
    namespace = "com.dailyasking.daily_asking"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dailyasking.daily_asking"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            val requiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            val missing = requiredKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
            if (missing.isNotEmpty()) {
                throw GradleException(
                    "android/key.properties 缺少字段: ${missing.joinToString(", ")}；" +
                        "请对照 android/key.properties.example 补全（见 docs/release-signing.md）。",
                )
            }
            val releaseStoreFile = file(keystoreProperties.getProperty("storeFile"))
            if (!releaseStoreFile.exists()) {
                throw GradleException(
                    "android/key.properties 的 storeFile 指向的文件不存在: ${releaseStoreFile.absolutePath}；" +
                        "该路径相对 android/app/ 解析，Windows 下建议直接写绝对路径。" +
                        "（见 docs/release-signing.md）",
                )
            }
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 有 android/key.properties → 正式签名；否则退回 debug 签名（便于本机/演示安装）。
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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

// 未配置正式签名却要出 release 包时，在日志里显式提醒一次（只提醒，不阻断构建）。
if (!hasReleaseSigning &&
    gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
) {
    logger.warn(
        "警告: 未找到 android/key.properties，release 包将使用 debug 签名，不可用于正式发布。" +
            "配置步骤见 docs/release-signing.md。",
    )
}
