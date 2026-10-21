allprojects {
    repositories {
        google()
        mavenCentral()
        mavenLocal()
        // PayHere's old repository (you can keep it just in case)
        maven {
            url = uri("https://repo.repsy.io/mvn/payhere/payhere-mobilesdk-android/")
        }
        // ADD JITPACK HERE FOR THE NEWER PAYHERE SDKs
        maven {
            url = uri("https://jitpack.io")
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