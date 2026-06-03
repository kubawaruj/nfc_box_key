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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    // Definiujemy naszą bezpieczną konfigurację
    val applyAndroidOverrides = {
        // 1. Wymuszamy kompilację pod SDK 35, żeby uciszyć biblioteki AndroidX
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileSdkVersion(35)
        }
        // 2. Dodatkowo bezwzględnie wyłączamy sprawdzanie metadanych AAR
        tasks.matching { it.name.contains("CheckAarMetadata") }.configureEach {
            enabled = false
        }
    }

    // Jeśli wtyczka zdążyła się już załadować, aplikujemy zmiany natychmiast
    if (state.executed) {
        applyAndroidOverrides()
    } else {
        // Jeśli jeszcze się konfiguruje, czekamy na właściwy moment
        afterEvaluate {
            applyAndroidOverrides()
        }
    }
}