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

subprojects {
    val configureAndroid: Project.() -> Unit = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val method = android.javaClass.getMethod("getCompileSdkVersion")
                val currentSdk = (method.invoke(android) as? String)?.replace("android-", "")?.toIntOrNull() ?: 0
                if (currentSdk in 1..33) {
                    val setMethod = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    setMethod.invoke(android, 34)
                }
            } catch (_: Exception) {}
        }
    }
    if (state.executed) {
        configureAndroid()
    } else {
        afterEvaluate { configureAndroid() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
