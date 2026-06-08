allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force-bump stale compileSdk values on Flutter plugins (e.g. flutter_appauth
// pins 31, but a transitive androidx.fragment dep requires 34+). Must be
// registered before any block that triggers subproject evaluation.
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.apply {
                if ((compileSdk ?: 0) < 34) {
                    compileSdk = 35
                }
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
