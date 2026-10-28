# Mordeviel — Legendary

Le nom principal est **Mordeviel** ; **Legendary** est son sous-titre.
Cette identité est confirmée pour l’ensemble du projet. Les appellations
précédentes restent uniquement dans les archives, les caches ignorés et les
consignes historiques de génération des images.
Le domaine public reste `https://legendeofwolf.newtechnologiestg.com`.

## Sources et configuration

- Application Flutter : `apps/mordeviel`, package Dart `mordeviel` et classe `MordevielApp`.
- Android : namespace et applicationId `com.mordeviel.mordeviel`.
- iOS : bundle `com.mordeviel.mordeviel` (et suffixe RunnerTests pour les tests).
- Windows : exécutable `mordeviel.exe`.
- Backend : distribution `mordeviel-api`, module `mordeviel_api`.
- Ressources originales : dossier `mordeviel/`.
- Invitations locales : protocole `mordeviel://join`.
- Variables du serveur : préfixe `MORDEVIEL_` ; la variable `SMTP_USE_TLS` reste inchangée.

Les anciens caches Flutter peuvent rester verrouillés par Windows dans l’ancien
dossier de compilation ; ce dossier est ignoré et ne fait pas partie des sources.

## Installation et déploiement

Depuis la racine :

```powershell
backend/.venv/Scripts/python.exe -m pip install -e './backend[dev]'
Set-Location apps/mordeviel
flutter pub get
flutter build apk --release
```

L’identifiant Android/iOS ayant changé, cette version est une application distincte
pour le système. Les préférences locales de l’ancienne installation ne migrent pas
automatiquement. Les comptes distants restent dans la même base serveur.
Les anciens QR doivent être régénérés par la nouvelle version.

Avant de publier sur le serveur existant, adapter son fichier d’environnement aux
nouvelles clés `MORDEVIEL_`, conserver les valeurs et le chemin de la base SQLite
existante, puis utiliser `uvicorn mordeviel_api.main:app` dans le service. Mettre à
jour les chemins du checkout et du processus Dart selon l’installation réelle.
Les exemples de service `mordeviel` dans la documentation supposent que le service
a été renommé. Ne pas créer une nouvelle base ni modifier le domaine public.
Aucun déploiement distant n’a été effectué lors du changement de nom local.

## Logo et captures

Le logo maître est `mordeviel/logo/logo_transparent.png`. Ses copies actives sont
`apps/mordeviel/assets/branding/logo.png` et
`backend/src/mordeviel_api/web/assets/logo.png`. Le script
`tools/update_app_icons.ps1` en dérive les icônes Android, iOS, Windows et Web.
Les captures du site proviennent des widgets Flutter via
`test/navigation_preview_test.dart` avec `CAPTURE_NAVIGATION=true`.

Logo produit avec l’outil intégré `image_gen.imagegen`, en édition de l’ancien
emblème, avec un véritable fond transparent. Consigne de génération : conserver
le cadre de bois et d’or, l’écusson bordeaux, la lune, les deux loups et le village ;
remplacer le grand titre par « MORDEVIEL » et le texte du parchemin par
« LEGENDARY », en gardant le style de lettres métalliques sculptées et sans autre
texte. Le résultat et les captures ont été inspectés visuellement.
