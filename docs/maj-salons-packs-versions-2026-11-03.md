# Salons, packs et nouvelles versions — 3 novembre 2026

## Entrée dans le village

Le dialogue d'entrée en ligne demande maintenant le pseudo **et** le choix explicite Masculin · Villageois / Féminin · Villageoise. Le choix est transmis au salon, y compris lorsque la connexion se lance automatiquement depuis une invitation ou un salon public. Le pseudo seul ne valide plus le formulaire ; la touche de validation du clavier ne permet pas de contourner le genre. Une nouvelle entrée redemande les informations. Le MDJ, qui ne reçoit pas de rôle, n'a pas cette obligation.

Le formulaire local refuse également de rejoindre tant que le choix n'a pas été effectué. Le champ ne sélectionne plus silencieusement Masculin par défaut. Les pouvoirs restent identiques : le choix sert à présenter la bonne carte de Simple Villageois et ses illustrations.

Un test réel de création de salon local a identifié une `PlatformException` du plugin de maintien de l'écran allumé. Cette option facultative ne peut plus interrompre la création ni empêcher le nettoyage d'une connexion. Le test valide que le village et ses commandes sont bien affichés même quand le plugin n'est pas disponible. Cela ne remplace pas un essai du salon sur chaque appareil.

## Cartes Intense téléchargeables

Le pack `intense-cards` regroupe **21 images, 25 349 052 octets, soit 24,17 Mio de ressources**. Les sources restent dans le dépôt pour la publication serveur. Leur dossier a été retiré des assets Flutter embarqués. Ce nombre est la taille brute retirée des ressources ; le gain exact sur l'APK ne sera connu qu'après le build.

Le lecteur de cartes utilise le cache persistant des packs. La création/configuration d'une partie Intense ou d'un mélange contenant des cartes Intense demande ce pack. La galerie propose aussi le téléchargement avant de changer de collection. Sans ces fichiers, le chemin ne tente pas de lire une image Intense absente de l'APK. L'environnement Intense et ses maisons restent embarqués dans cette mise à jour.

## Détecteur de mise à jour Android

> Cette section décrit le fonctionnement initial. La version actuelle du projet est désormais `0.3.3+3` ; un changement de lien à version égale ne demande plus de réinstallation. Consulter [Version de l’application](version-application.md) pour le fonctionnement et la procédure de publication à jour.

Le build préparé est **0.2.0+2**. Après la vidéo d'ouverture, l'application consulte `/app-update` avant l'accueil, le hurlement et le Collectionneur. L'API reprend directement les champs déjà présents dans l'administration du site : version, lien MEGA et activation des téléchargements. Le bouton **Enregistrer le lien de téléchargement** publie donc aussi l'annonce de nouvelle version.

Le numéro saisi doit correspondre au vrai APK : `0.2.0+2`, puis par exemple `0.2.1+3` pour une publication suivante. Les versions sont comparées numériquement et le numéro de build est pris en compte lorsqu'il est renseigné. Un changement du lien complet, y compris de sa clé après `#`, change également l'empreinte de publication.

Une version plus récente produit une alerte bloquante **Mise à jour disponible**. **Télécharger la mise à jour** ouvre directement le lien enregistré via MEGA ou le navigateur, sans retour sur la vitrine Mordeviel. L'installation reste le parcours habituel d'Android. Cliquer ou revenir depuis le lien ne marque jamais une version comme installée. Le bouton **Vérifier à nouveau** et le retour au premier plan contrôlent à nouveau la version réelle. Pour un lien modifié à version identique, le changement de date d'installation du paquet permet de confirmer une véritable réinstallation ; il reste préférable d'augmenter la version à chaque publication.

Une vérification initiale impossible faute de réseau ne bloque pas les parties locales. Une annonce déjà affichée reste bloquante si une vérification suivante échoue. Aucun dialogue ne surgit au milieu d'une partie : ce contrôle est placé au démarrage, après la vidéo.

Le lien existant du site distribue un **APK Android**. Le détecteur ne l'impose donc pas à Windows ou à iOS. Un futur canal d'installation Windows devra disposer de sa propre version et de son propre lien. Les anciennes applications qui ne contiennent pas encore ce détecteur doivent recevoir manuellement ce premier APK ; les publications suivantes pourront ensuite être annoncées automatiquement.

`package_info_plus` lit la version installée et `url_launcher` ouvre le téléchargement. Les paquets ont été résolus depuis le cache local, sans compilation de l'application.

## Publication sur Contabo

Après le commit/push et le `git pull` habituels, depuis `/var/www/Le-loup` :

```bash
backend/venv/bin/python tools/content/build_packs.py
sudo systemctl restart legendeofwolf
```

Construire ensuite l'application avec les commandes Flutter habituelles. Publier son lien MEGA dans l'administration en recopiant sa version exacte et en activant les téléchargements. Ne pas désinstaller l'ancienne application pour appliquer une mise à jour : le cache des packs se conserve lors d'une installation par-dessus avec la même identité de signature.

Aucun APK ni exécutable Windows n'a été compilé et aucun serveur distant n'a été modifié par l'agent.

## Prochain concept à discuter

**La Soirée de Mère-grand** : la discussion avec Logan a défini un jeu chibi 3D à part entière, avec Rubine, Pèlerine et le Loup, jusqu’à vingt joueurs et un MDJ. Le fonctionnement convenu et les propositions à tester sont décrits dans [le document de conception](soiree-de-mere-grand-fonctionnement.md). Les [prompts de personnages](soiree-de-mere-grand-prompts-chibi.md) préparent leurs références visuelles et leur fabrication 3D. Le développement du mode n’est pas encore engagé.
