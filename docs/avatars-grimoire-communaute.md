# Grimoire, portraits et communauté — 2 novembre 2026

## Grimoire de la partie

Le Codex devient un livre en parchemin avec couverture, reliure et folios. En portrait, une feuille est visible ; en paysage, deux pages sont ouvertes. Les textes sont répartis en mesurant les lignes à la taille de caractères choisie. Un chapitre trop long continue sur une nouvelle feuille, sans réduire la police pour le faire tenir. Le feuilletage fonctionne par glissement, boutons ou flèches du clavier ; un sommaire mène directement à un rôle. Le changement d’orientation conserve le passage en cours. La réduction des mouvements supprime la rotation animée.

Le contenu vient uniquement de la composition publique et des réglages du salon. Il décrit toutes les éditions effectivement présentes et ne consulte jamais les attributions secrètes.

## Portraits liés aux comptes

- Quatre portraits sont disponibles au départ : **Villageois, Villageoise, Loup-Garou, Voyante**. Le serveur en attribue un au hasard à la création du compte, puis conserve le choix entre les connexions. Les anciens comptes reçoivent un premier portrait à leur prochaine connexion/consultation.
- Les vingt portraits Classiques sont présentés dans le catalogue. Les seize autres sont verrouillés et annoncés comme récompenses de défis à venir. Aucune condition de défi ou acquisition payante n’est inventée. Le serveur refuse une sélection non débloquée, même avec une requête manuelle.
- La table `avatar_unlocks` prépare les récompenses futures ; aucun endpoint joueur ne permet de s’octroyer une récompense.
- Les visages sont cadrés à partir des illustrations existantes, sans régénérer les personnages. Les métadonnées de cadrage sont dans `shared/avatars/catalog.json`. Les images sont distribuées dans **avatars-classic**, hors des ressources d’avatars de l’APK. Les originaux des cartes restent nécessaires au jeu classique.
- Le catalogue d’avatars se trouve en haut de « Découvrir les cartes ». On peut modifier son portrait depuis le profil communautaire et le carnet de joueur. Les profils visités affichent le même choix.
- Une photo personnelle peut remplacer un avatar. Le sélecteur natif accepte PNG/JPEG/WebP, prépare un carré léger et affiche une confirmation. Le serveur valide et réencode les pixels en WebP 384 × 384, sans EXIF. Les photos nécessitent une authentification, sont masquées aux comptes bloqués et sont supprimées lors du remplacement ou de la suppression du compte.

La photo personnelle est un fichier propre au compte, pas une ressource du pack collectif. La disparition d’un pack sur un appareil n’efface ni le choix enregistré ni les droits du compte.

## Chat communautaire

Les messages affichent le portrait actuel de l’auteur, son pseudo, sa certification éventuelle, l’heure et des séparateurs de date. Les messages personnels sont alignés à droite, les autres à gauche, dans la palette du chat privé. Le portrait et le pseudo ouvrent le profil existant, où l’on peut demander l’amitié, accepter/refuser une demande, consulter les statistiques autorisées ou bloquer le joueur. Le signalement reste accessible dans les options du message.

Le champ de saisie conserve son contrôleur, son focus et le nouveau brouillon pendant les actualisations. Les stickers restent disponibles. Les règles de modération et les restrictions de trois heures restent appliquées par le serveur.

La déconnexion n’attend pas plus de deux secondes un envoi de présence « hors ligne ». La synchronisation des accès aux notifications reste ordonnée avant leur révocation et la suppression de la session.

## Hibou Horreur

La caméra libre pouvait placer son ancien perchoir hors écran et rendre le hibou trop petit en vue d’ensemble. Le perchoir est maintenant borné dans la zone visible, avec une branche de bordure si nécessaire. Sa taille minimale est 44 pixels et son échelle utilise les axes de l’écran. Le premier vol commence à 12 secondes, rejoint la caméra, revient entre 18 et 21 secondes, puis le hibou retrouve sa branche. Le cri accompagne ce nouveau moment. Le début d’une nuit réinitialise le cycle, même si le numéro n’a pas changé.

Pause, arrière-plan, réduction des mouvements et désactivation des frayeurs restent respectés. Les images nécessitent le pack Village Horreur et les sons le pack Ambiances Horreur. Le mode local conserve la diffusion sonore sur l’appareil du MDJ.

## Déploiement

Depuis la racine du dépôt sur Contabo, après publication des changements puis `git pull` :

```bash
cd /var/www/Le-loup
backend/venv/bin/python tools/content/build_packs.py
sudo systemctl restart legendeofwolf
curl --retry 5 --retry-delay 2 -fsS https://mordeviel.newtechnologiestg.com/health
```

Le catalogue contient désormais **13 packs**, dont Avatars Classiques. Les tables de portraits et de récompenses sont créées automatiquement ; les comptes et leurs statistiques sont conservés. Ne supprime pas `backend/data` ni les versions précédentes des packs.

Sur le PC, depuis `apps/mordeviel`, exécuter `flutter pub get` avant le prochain build : `file_selector` ajoute la sélection native d’une photo. Aucun APK ni exécutable Windows n’a été compilé dans cette intervention.

## Vérifications effectuées

- **206 tests Flutter ciblés passent** : variantes, contrôles de jeu, cartes, grimoire, orientations, textes agrandis, avatars, saisie des chats, sessions, profils, cartes du village, bots et téléchargements.
- **32 tests backend passent**, dont les scénarios de salons réels avec le moteur Dart, les amis, les droits administrateur, les portraits, les photos, leur suppression et la vérification email.
- L’analyse statique du code applicatif et du moteur Dart est sans anomalie. Les scripts de génération et le nouveau module de portraits passent Ruff.
- Les aperçus du grimoire portrait/paysage, des quatre avatars et du chat communautaire ont été inspectés avec les polices et les images réelles. Les nouveaux rectos Intense/Horreur et la carte Intense ont aussi leurs aperçus.

Le banc FastAPI sous Windows signale des avertissements de dépréciation de TestClient et de fermeture de transports de sous-processus ; les scénarios réussissent. Aucun serveur Contabo n’a été modifié et aucun essai sur les téléphones physiques n’a été effectué par l’agent.
