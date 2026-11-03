# Ouverture vidéo Gemini — 3 novembre 2026

L'ouverture utilise la vidéo portrait fournie par Logan : `gemini_generated_video_bd65af76.mp4`. La narration Gemini est remplacée par la voix masculine Intense déjà approuvée dans le jeu, générée localement avec Qwen3-TTS. Elle dit : « Bienvenue dans Mordeviel Legendary… que la traque commence. » La pause est de 0,72 seconde et la seconde phrase est légèrement ralentie sans changer le timbre. Les griffures, le rideau et le logo de la vidéo restent présents. Les sous-titres incrustés sont retirés. La musique originale du jeu remplace la bande sonore contenant déjà une voix, avec une atténuation pendant la réplique et une courte réverbération sombre.

## Sauvegarde de l'ancienne version

`media/opening/archive-native-2026-11-03/ouverture-native-complete.zip` contient les fichiers exacts de l'ouverture native avant remplacement : les deux composants, les textures, le logo, les trois sons, les tests, la configuration et la documentation. Le README explique la restauration. Les 20 fichiers de l'archive ont été contrôlés avec leur empreinte SHA-256.

Le MP4 historique inclus montre le rideau seul ; le code archivé contient bien le chargement du logo sous le rideau, son reflet et la séquence complète de 5,6 secondes. Cette archive n'est pas embarquée dans l'application.

## Nouvelle séquence

- Ressource locale : `apps/mordeviel/assets/branding/opening/intro_gemini.mp4` ; aucun téléchargement requis.
- Durée : 10 secondes, **720 × 1280** à 24 images/s, H.264 et AAC stéréo. Le fichier embarqué conserve la résolution native, avec ouverture rapide et environ **2,3 Mio**. L’export de présentation en **1080 × 1920**, agrandi proportionnellement, est disponible dans `exports/intro-mordeviel/mordeviel-intro-qwen-1080x1920.mp4`.
- Le format portrait remplit naturellement mieux le téléphone. Dans les deux orientations, l'image complète conserve ses proportions au centre ; une vue agrandie, assombrie et floutée du même film remplit les marges éventuelles. Le logo n'est ni étiré ni coupé. Les deux vues partagent un seul lecteur.
- La rotation réutilise le lecteur et conserve la position de lecture.
- « Passer » reste accessible dans une zone sûre et attend aussi la préparation de l'application.
- Le mixage suit le volume des effets et le mode silencieux enregistrés. La musique de l'accueil ne joue pas sous le film. La vidéo est mise en pause avant l'accueil, qui retrouve son hurlement et sa musique habituels.
- La mise en arrière-plan met la vidéo et son son en pause ; le retour reprend la lecture. La réduction des mouvements utilise un logo statique.
- Si un codec manque, si l'initialisation dépasse six secondes ou si la lecture reste figée huit secondes au premier plan, un logo statique permet d'accéder au jeu. L'écran ne reste pas bloqué sur le lecteur.

## Lecteurs et vérifications

Android utilise [video_player](https://pub.dev/packages/video_player). Windows utilise son implémentation [video_player_win](https://pub.dev/packages/video_player_win), fondée sur Media Foundation, sans bibliothèque vidéo lourde supplémentaire. Les dépendances, le verrouillage et l'enregistrement du plugin Windows ont été mis à jour.

La nouvelle vidéo a été décodée intégralement, image et son, avec FFmpeg, sans erreur. Les tests Flutter couvrent la fin unique, le passage anticipé, la préparation, la pause/reprise, la rotation, le volume nul, les erreurs de lecture, les mouvements réduits et le cadrage de vidéos portrait et paysage dans les deux orientations d'écran. Ces contrôles ne remplacent pas un essai du décodage natif sur téléphone.

Aucun APK ni exécutable Windows n'a été compilé. Aucun changement de serveur n'est nécessaire.

La précédente vidéo portrait est sauvegardée dans `media/opening/archive-video-2026-11-03/intro-before-qwen-4d9bc3be9e38.mp4`. La provenance, les empreintes et les paramètres audio sont conservés dans `tools/audio/opening_narration.json`. Les scripts `create_opening_voice.py` puis `compose_opening_narration.py --source ... --ffmpeg ... --apply` reproduisent le montage avec le Python Qwen local. Les références vocales validées restent inchangées.
