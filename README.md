# AI RAW Editor

Projet Flutter de retouche photo avec import d'images classiques et décodage de fichiers RAW via LibRaw.

## Compilation Android avec GitHub Actions

Le workflow `.github/workflows/build-apk.yml` :

1. installe Flutter et Java 17 ;
2. régénère le projet Android manquant ;
3. installe l'Android NDK ;
4. compile LibRaw en ARM64 ;
5. place `libraw.so` dans `jniLibs/arm64-v8a` ;
6. lance `flutter analyze` ;
7. génère `app-release.apk` ;
8. publie l'APK comme artifact GitHub Actions.

Dans GitHub : **Actions → Build AI RAW Editor APK → Run workflow**.

L'APK se trouve ensuite dans **Artifacts → ai-raw-editor-release**.
