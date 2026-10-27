# Legende of Wolf

Application Flutter — by Logan R.D.

Serveur public par défaut : https://legendeofwolf.newtechnologiestg.com
Les salons en ligne, la communauté, les comptes, la maintenance et la boutique
utilisent cette adresse commune (lib/services/server_config.dart).
Le mode local conserve son serveur Dart sur l'appareil du maître du jeu.

## Compiler depuis PowerShell

Depuis la racine du dépôt :

```powershell
Set-Location apps/le_loup
flutter pub get
flutter build apk --release
```

APK : build/app/outputs/flutter-apk/app-release.apk

Pour Windows :

```powershell
flutter build windows --release
```

Distribuer tout le dossier build/windows/x64/runner/Release.

## Serveur de développement

La surcharge reste disponible sans modifier les sources :

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Sur émulateur Android, utiliser http://10.0.2.2:8000 pour accéder au PC.

## Publication Android

Le projet utilise actuellement la signature de développement pour les builds
release. Avant une publication Google Play, configurer une clé de signature
production dans Gradle (voir SIGNING.md), puis générer l'App Bundle avec
`flutter build appbundle --release`.
Les secrets SMTP et le .env du backend restent uniquement sur le serveur.
