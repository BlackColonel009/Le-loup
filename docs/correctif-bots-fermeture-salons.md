# Bots et fermeture des salons en ligne — 4 novembre 2026

- Le bouton « Ajouter des joueurs virtuels » est placé avant la carte dans le village, et en tête des pages Préparation et Actions. Il reste réservé au MDJ du salon en ligne ; les tests locaux conservent leur contrôle administrateur. L’ajout reste limité à l’avant-partie.
- Une fermeture confirmée du salon envoie aux joueurs un événement `room.closed`, puis ferme leur WebSocket avec le code applicatif `4004`.
- Le client arrête les tentatives de reconnexion pour un salon fermé. Une coupure réseau temporaire conserve la reprise automatique et l’état prêt.
- La fermeture par le MDJ et les départs volontaires en ligne conduisent à « Les villages en ligne ». La liste est rechargée ; le salon, les dialogues et les écrans ouverts au-dessus de lui sont retirés de la navigation.
- La fermeture continue d’exiger le jeton privé du MDJ. Le retrait du salon public et l’annulation des invitations utilisent le mécanisme serveur existant.

Les contrôles couvrent le bouton visible sans défilement, son action d’ajout, le retour du MDJ, l’éjection du joueur même avec un autre écran ouvert, l’absence de reprise après fermeture, la reprise après coupure et les bots avec le véritable moteur Dart.

Pour déployer : publier les modifications de l’application, du package `local_host` et du backend. Après le pull sur Contabo, redémarrer `legendeofwolf`, puis reconstruire l’application. Aucun nouveau pack ni dépendance n’est nécessaire. Aucun APK n’est construit par ces vérifications.
