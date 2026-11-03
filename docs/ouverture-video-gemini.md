# Ouverture vidéo Gemini — 3 novembre 2026

L'ouverture utilise maintenant la vidéo créée avec Gemini et fournie par Logan : `gemini_generated_video_994fdc96.mp4`. Elle contient les griffures, l'ouverture du rideau, le logo et le son ; l'ancien rideau Flutter et ses sons ne sont pas joués en plus.

## Sauvegarde de l'ancienne version

`media/opening/archive-native-2026-11-03/ouverture-native-complete.zip` contient les fichiers exacts de l'ouverture native avant remplacement : les deux composants, les textures, le logo, les trois sons, les tests, la configuration et la documentation. Le README explique la restauration. Les 20 fichiers de l'archive ont été contrôlés avec leur empreinte SHA-256.

Le MP4 historique inclus montre le rideau seul ; le code archivé contient bien le chargement du logo sous le rideau, son reflet et la séquence complète de 5,6 secondes. Cette archive n'est pas embarquée dans l'application.

## Nouvelle séquence

- Ressource locale : `apps/mordeviel/assets/branding/opening/intro_gemini.mp4` ; aucun téléchargement requis.
- Durée : environ 10 secondes, 1280 × 720 à 24 images/s, H.264 et AAC stéréo. Le conteneur MP4 a été réorganisé pour une ouverture rapide, **sans recompression des images ni du son**. Taille embarquée : 4 028 993 octets (3,84 Mio).
- En paysage, la vidéo conserve ses proportions. En portrait, l'image complète reste visible au centre ; une vue agrandie, assombrie et floutée du même film remplit l'arrière-plan. Le logo n'est ni étiré ni coupé. Les deux vues partagent un seul lecteur.
- La rotation réutilise le lecteur et conserve la position de lecture.
- « Passer » reste accessible dans une zone sûre et attend aussi la préparation de l'application.
- Le son d'origine suit le volume des effets et le mode silencieux enregistrés. La musique de l'accueil ne joue pas sous le film. La vidéo est mise en pause avant l'accueil, qui retrouve son hurlement et sa musique habituels.
- La mise en arrière-plan met la vidéo et son son en pause ; le retour reprend la lecture. La réduction des mouvements utilise un logo statique.
- Si un codec manque, si l'initialisation dépasse six secondes ou si la lecture reste figée huit secondes au premier plan, un logo statique permet d'accéder au jeu. L'écran ne reste pas bloqué sur le lecteur.

## Lecteurs et vérifications

Android utilise [video_player](https://pub.dev/packages/video_player). Windows utilise son implémentation [video_player_win](https://pub.dev/packages/video_player_win), fondée sur Media Foundation, sans bibliothèque vidéo lourde supplémentaire. Les dépendances, le verrouillage et l'enregistrement du plugin Windows ont été mis à jour.

La vidéo a été décodée intégralement, image et son, avec FFmpeg. Les tests Flutter couvrent la fin unique, le passage anticipé, la préparation, la pause/reprise, la rotation, le volume nul, les erreurs de lecture, les mouvements réduits et le cadrage dans les deux orientations. Les captures de cadrage utilisent une image extraite du film dans le véritable composant Flutter ; elles ne remplacent pas un essai du décodage natif sur téléphone.

Aucun APK ni exécutable Windows n'a été compilé. Aucun changement de serveur n'est nécessaire.
