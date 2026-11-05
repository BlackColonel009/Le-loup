# Parchemin, bilan et annonces illustrées

* Sulfuron : parchemin déroulé sur les appareils recevant son événement public,
  titre puis identité annoncée écrite avec lueur de braise. Le Bluff reste signalé
  comme potentiellement mensonger et ne change jamais le rôle réel.
* Fin de partie : le bouton du bilan ouvre d’abord la grille des joueurs. Le
  serveur en ligne ajoute les avatars et pseudos de compte uniquement après la
  fin. L’onglet des manches conserve l’historique détaillé. En local, un joueur
  sans compte associé garde un portrait de remplacement avec son initiale.
* Dashboard web : jusqu’à huit images PNG/JPEG/WebP par annonce, sélectionnées
  dans les cartes de la vitrine ou depuis des fichiers (4 Mo et 4096 px maximum).
  Le serveur réencode les fichiers, filtre les chemins et réserve la publication
  aux administrateurs. Le site et l’application affichent les mêmes pièces
  jointes. Une image téléversée n’est accessible publiquement qu’une fois publiée.
  Les emails gardent leur bouton de diffusion existant et renvoient vers le site.
* Vocal : session audio partagée Android/iOS afin de préserver les sons du jeu,
  débit vocal « speech » avec DTX conservé. Les requêtes d’accès et connexions
  vocales sont bornées ; après échec, reprise progressive espacée de 4 à 32 s.
  Le salon utilise toujours sa connexion distincte. La reconnexion vocale ne
  retarde pas les commandes de jeu. La voix du MDJ garde la priorité sur l’émission
  du micro. La stabilité et le mixage audio restent à vérifier sur appareils
  Android réels, notamment lors d’un passage Wi-Fi/données mobiles.

Déploiement : nouvelle version de l’application et redémarrage du backend après
transfert du dépôt. La colonne des images est ajoutée automatiquement aux bases
existantes au démarrage. Aucun envoi d’annonce ni email réel n’est lancé par les
tests de cette mise à jour.
