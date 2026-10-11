allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Force all subprojects (including plugin subprojects) to use the same AGP
    // version. Plugins declare their own AGP version in buildscript classpath,
    // which causes Gradle to download multiple conflicting AGP versions.
    buildscript {
        configurations.all {
            resolutionStrategy {
                force("com.android.tools.build:gradle:9.0.1")
            }
        }
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
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }

    // Force every Android library/application subproject (e.g. sentry_flutter,
    // flutter_file_downloader which hardcode compileSdk 34) to compile against
    // SDK 36+. Otherwise `package_info_plus >= 10` fails checkAarMetadata with:
    // "Dependency ':package_info_plus' requires ... compile against version 36
    //  or later ... :sentry_flutter is currently compiled against android-34."
    // Uses reflection so this script compiles without an AGP dependency.
    afterEvaluate {
        extensions.findByName("android")?.let { androidExt ->
            try {
                val getCompileSdk =
                    androidExt.javaClass.getMethod("getCompileSdk")
                val current = getCompileSdk.invoke(androidExt) as? Int ?: 0
                if (current in 1..35) {
                    androidExt.javaClass
                        .getMethod("setCompileSdk", Int::class.javaPrimitiveType)
                        .invoke(androidExt, 37)
                }
            } catch (_: Exception) {
                try {
                    val getV =
                        androidExt.javaClass.getMethod("getCompileSdkVersion")
                    val current =
                        getV.invoke(androidExt)?.toString()
                            ?.removePrefix("android-")?.toIntOrNull() ?: 0
                    if (current in 1..35) {
                        try {
                            androidExt.javaClass
                                .getMethod(
                                    "setCompileSdkVersion",
                                    Int::class.javaPrimitiveType,
                                ).invoke(androidExt, 37)
                        } catch (_: Exception) {
                            androidExt.javaClass
                                .getMethod(
                                    "setCompileSdkVersion",
                                    String::class.java,
                                ).invoke(androidExt, "android-37")
                        }
                    }
                } catch (_: Exception) {
                    // Not an Android module — nothing to do.
                }
            }
        }
    }

    // Ensure Java compile settings for subprojects to avoid legacy Java 8 warnings
    tasks.withType<JavaCompile> {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
        // Add deprecation lint to help locate deprecated API usage in dependencies
        options.compilerArgs.add("-Xlint:deprecation")
    }

    // Force Kotlin compiler options for subprojects (e.g. sentry_flutter hardcoding languageVersion = "1.6")
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
            apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
        }
    }

    // Force an AndroidX compatibility artifact so legacy support library references are satisfied
    configurations.all {
        resolutionStrategy {
            // Use the latest version published: https://central.sonatype.com/artifact/com.google.crypto.tink/tink-android
            val tink = "com.google.crypto.tink:tink-android:1.17.0"
            force(tink)
            dependencySubstitution {
                substitute(module("com.google.crypto.tink:tink")).using(module(tink))
            }
        }
        resolutionStrategy.force("androidx.legacy:legacy-support-core-utils:1.0.0")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
