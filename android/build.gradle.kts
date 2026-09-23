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

    // Ensure Java compile settings for subprojects to avoid legacy Java 8 warnings
    tasks.withType<JavaCompile> {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
        // Add deprecation lint to help locate deprecated API usage in dependencies
        options.compilerArgs.add("-Xlint:deprecation")
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
