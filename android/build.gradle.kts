import com.android.build.gradle.LibraryExtension

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

// AGP 7.3+/8+ requires a namespace for library modules. Some older plugin packages
// in the pub cache may not declare a namespace in their module build.gradle.
// Provide a safe fallback: if a subproject is an Android library and its
// namespace is missing, set it to the app's applicationId (or a default).
subprojects {
    plugins.withId("com.android.library") {
        // configure the android extension if present
        extensions.configure<LibraryExtension>("android") {
            try {
                if (namespace.isNullOrBlank()) {
                    // Use the app's package as a sensible default
                    namespace = "com.example.sampah_online"
                }
            } catch (e: Exception) {
                // swallow any exception here to avoid failing the configuration step
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
