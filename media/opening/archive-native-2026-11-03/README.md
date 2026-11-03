# Ancienne ouverture native — sauvegarde du 3 novembre 2026

`ouverture-native-complete.zip` conserve les fichiers exacts avant le remplacement par la vidéo Gemini : rideau déchiré, deux mains et poussière, sons, logo, chargement avec reflet, tests et configuration.

Séquence native : griffures à 0,38 s et 1,10 s, déchirure à 1,67 s, rideau ouvert à 3,8 s ; logo sur fond vert sombre, reflet et barre de chargement jusqu’à 5,6 s. Le bouton Passer et la pause en arrière-plan étaient disponibles.

Le MP4 inclus représente le rideau seul (3,8 s), créé avant le retour du logo. La capture `opening_logo.png` montre le logo rétabli. Le code `opening_screen.dart` dans cette archive contient bien la version complète de 5,6 s, avec le logo sous le rideau.

Les chemins de l’archive sont relatifs à la racine du dépôt. Pour restaurer, reprendre les deux composants `opening_screen.dart` et `opening_curtain.dart`, leurs ressources et les lignes correspondantes du pubspec et de `_Entrance` dans main.dart. Les copies de main.dart et classic_audio.dart servent de référence : ne pas écraser les autres mises à jour de ces fichiers.

`manifest.json` contient les tailles et SHA-256. Cette archive reste hors des ressources Flutter et n’alourdit pas l’APK.
