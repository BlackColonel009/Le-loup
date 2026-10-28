# Collections et Collectionneur

## Accès et acquisition

Les vingt cartes classiques (dont la Villageoise, les Sœurs et le Maire) sont acquises automatiquement. Les éditions Intense/Horreur modifient l’apparence et proposent maintenant des pouvoirs spécifiques pour la Voyante, le Métamorphe, le Salvateur et le Loup-Garou ; les autres rôles gardent leurs pouvoirs actuels. Voir variantes-premiers-quatre-roles.md. Le catalogue comprend également huit packs de voix et deux environnements. La collection d’un compte est persistée dans SQLite ; les classiques restent consultables dans l’application sans réseau. Le Codex public continue d’expliquer les rôles.

L’accès temporaire et la propriété sont distincts. Une acquisition gratuite autorisée est conservée après la période de découverte. Un simple essai n’attribue pas la carte. L’ajout est impossible tant que l’administrateur n’a pas publié de prix ; zéro est un prix gratuit valide. Pendant la phase gratuite, même un prix prévu positif conduit uniquement à un ajout gratuit : le serveur enregistre zéro débité. Après cette phase, les ajouts à prix positif sont refusés tant qu’un vrai système de paiement vérifié n’existe pas. Aucun client ne peut s’attribuer un produit ou un bonus en envoyant son propre prix.

Par défaut, la découverte dure 30 jours à partir de la première initialisation de cette version sur le serveur. L’administrateur peut fixer entre 1 et 3650 jours à partir d’aujourd’hui. Les dates sont inclusives, en UTC (également l’heure du Togo). Le prix est remplacé par « Gratuit · encore N jours » lorsqu’un accès temporaire s’applique. Les cartes acquises ne portent pas ce compte à rebours.

## Utilisation dans le dashboard

Dans l’application : Administration → Boutique → Collections, restrictions et Collectionneur. Sur le site : Administration → Collections & restrictions.

- **Activer les restrictions — test** : désactive l’accès gratuit global. Les Intense/Horreur non acquises et hors essai deviennent sombres et verrouillées ; les classiques restent acquises.
- **Rétablir l’accès gratuit** : remet la découverte. Si sa date a expiré, la durée configurée repart à partir d’aujourd’hui.
- **Appliquer cette durée** : fixe la fin de la gratuité à partir du jour courant. Le nombre restant apparaît aux joueurs.
- **Produits** : publier/retirer le prix, choisir la devise, masquer un article, choisir sa présence boutique/Collectionneur et attribuer jusqu’à dix bonus. Les bonus sont accordés avec l’acquisition, sans cascade récursive.
- **Offres quotidiennes** : remplacer manuellement les cinq cartes du jour, avec au plus une voix et un environnement supplémentaires.
- **Essais gratuits** : programmer une plage de jours, pour tous les produits (sélection vide) ou une sélection. Supprimer l’essai retire seulement son accès temporaire.

Les cartes Intense ont un cadenas doré ; les Horreur sont retenues par des chaînes et un cadenas. Les secousses sont brèves et décalées entre les cartes. La préférence système de réduction des animations est respectée. Les restrictions sont également vérifiées côté passerelle pour la création/configuration et le lancement des salons en ligne, selon la collection du MDJ. Les participants bénéficient des visuels choisis par le MDJ. Le futur paiement nécessitera encore la validation des reçus de la plateforme et une politique de licence hors connexion ; aucun paiement n’est activé par ce travail.

## Le Collectionneur

Personnage original : marchand de curiosités, velours bordeaux, chapeau extravagant, sourire rusé et cartes dorées. Les illustrations `collector.png`, `gold_lock.png` et `horror_chains.png` ont été générées avec imagegen et copiées dans `apps/mordeviel/assets/store/`. Le rire d’ambiance actuellement branché est celui déjà disponible dans le pack Horreur (`witch_laugh.wav`), réutilisé à la demande et selon le volume d’effets ; il n’est pas un nouvel enregistrement de comédien. Il faut télécharger ce pack pour l’entendre.

La sélection quotidienne est commune à tous et conservée en base, calculée d’après le jour UTC et les produits éligibles : cinq cartes, avec une probabilité déterministe d’environ 1/10 pour une voix et 1/20 pour un environnement. Elle change à minuit UTC et est préparée à la première consultation de la journée, sans cron supplémentaire. Une sélection masquée ou retirée ne peut pas être réclamée à partir d’un ancien écran. Si moins de cinq cartes restent éligibles, le comptoir n’invente pas de produits manquants.

Après le hurlement d’ouverture, une fenêtre présente le marchand, ses produits et un message d’invitation. Elle propose « Voir les trouvailles » et « Continuer l’aventure », ainsi qu’une croix de fermeture. Un compte connecté la voit au plus une fois par jour, y compris s’il utilise plusieurs appareils ; un visiteur sans compte a une préférence quotidienne par installation. Aucun popup ne coupe un salon déjà ouvert. Une absence de réseau laisse l’accueil utilisable. Le bouton Boutique → Collectionneur permet de retrouver les offres ensuite.

## Déploiement et données

Les tables sont créées automatiquement au démarrage de FastAPI dans la base communauté : produits, acquisitions, essais, sélections quotidiennes et dernier jour de présentation. Sauvegarder la base avant mise à jour ; les acquisitions sont supprimées avec le compte. Le serveur doit être mis à jour avant de tester le dashboard et la nouvelle application. Aucun changement SMTP, DNS ou Firebase n’est requis. Aucun APK n’a été compilé.

Tests : acquisition idempotente, prix absent, paiement refusé, bonus, droits admin, durée et expiration, essais ciblés/globaux, rotation et fenêtre quotidienne, animations et réduction du mouvement, affichage des jours gratuits et fermeture de la fenêtre.
