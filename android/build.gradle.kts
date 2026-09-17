allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// file_picker 11.0.3 的 android/build.gradle 只在 AGP < 9 时应用 KGP，其余情况指望 AGP 内置
// Kotlin；而本项目按 Flutter 迁移器的默认值设了 android.builtInKotlin=false，于是 AGP 9 下
// 插件的 .kt 无人编译，release 构建报「找不到符号 FilePickerPlugin」。
// Flutter 自身的补救也失效：它按文本扫到插件里出现过 KGP，就不再代为应用。
// 这里照上游已修版本的判断补上，jvmTarget 与插件 compileOptions 的 Java 17 对齐。
// file_picker 升到含该修复的版本后即可删除本段。
findProject(":file_picker")?.let { filePicker ->
    val agpMajor =
        com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
            .substringBefore('.')
            .toInt()
    val builtInKotlin = providers.gradleProperty("android.builtInKotlin").orNull
    val builtInKotlinEnabled = agpMajor >= 9 && (builtInKotlin == null || builtInKotlin.toBoolean())
    if (!builtInKotlinEnabled) {
        filePicker.pluginManager.apply("org.jetbrains.kotlin.android")
        filePicker.extensions
            .configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
