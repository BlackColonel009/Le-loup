# Boutique en Lunes d’or — 0.3.5

La boutique propose chaque jour trois stickers, trois cartes Intenses et trois bordures. La sélection, identique pour tous les comptes, change à minuit UTC (heure du Togo). L’application affiche le décompte et recharge les offres au changement de jour ou à son retour au premier plan. Un produit masqué ou désactivé peut réduire le nombre d’offres.

Prix initiaux et minimums imposés par le serveur : sticker 200, carte Intense 900, bordure 500 Lunes d’or. Les cartes classiques restent acquises automatiquement. Les cartes Horreur, thèmes complets et voix ne sont pas ajoutés à ces ventes en monnaie virtuelle.

Dans **Dashboard → Collections & Collectionneur → Produits, prix et bonus**, modifier le champ **Prix en Lunes d’or**. Un champ vide désactive cette vente. Les cases Visible et Boutique ainsi que les bonus restent applicables. Les prix en monnaie réelle sont séparés ; aucun paiement réel n’est activé. Les produits Intenses ou stickers proposés par le Collectionneur peuvent aussi être achetés en lunes, au même prix serveur, pendant leur offre quotidienne.

Le joueur confirme le prix et son futur solde avant l’achat. Le serveur contrôle la sélection du jour, le prix affiché, la propriété et les fonds dans une seule transaction. L’acquisition, le débit et l’historique sont enregistrés ensemble. Les répétitions, achats concurrents, offres périmées ou prix modifiés ne peuvent pas débiter deux fois ni rendre le solde négatif. Les acquisitions survivent à la fin d’un essai, aux mises à jour et aux réinstallations après reconnexion au compte.

Les stickers achetés deviennent utilisables dans les chats. Les bordures se sélectionnent depuis le profil. Les cartes Intenses sont disponibles dans la collection et peuvent être utilisées dans une composition mixte ; acheter une carte n’accorde pas l’environnement Intense complet. Les packs graphiques existants restent à télécharger séparément.

## Cadeau du Créateur

En 0.3.5, un message offre **100 Lunes d’or** signées Logan R.D aux comptes connectés, anciens et nouveaux. Le joueur peut réclamer ce cadeau depuis l’accueil après l’introduction, après sa connexion, ou plus tard depuis **Ma bourse**. Une seule attribution est permise par compte, même avec plusieurs appareils, une réinstallation ou des requêtes simultanées. Le message n’interrompt pas les parties en cours. Le cadeau et les achats apparaissent dans la bourse ; les achats apparaissent aussi dans l’historique du profil.

## Publication

La version Flutter est `0.3.5+5`. Aucun APK n’est compilé par cette modification. Après publication du code et `git pull` sur Contabo, redémarrer `legendeofwolf`. La migration SQLite et les prix initiaux s’appliquent automatiquement au démarrage, sans effacer les soldes ou collections et sans réinitialiser ensuite les prix administrateur.

```bash
cd /var/www/Le-loup
git pull
sudo systemctl restart legendeofwolf
curl --retry 5 --retry-delay 2 -fsS https://mordeviel.newtechnologiestg.com/health
```

Construire ensuite la nouvelle application et publier son lien/version dans le dashboard habituel. Les anciennes applications ne présentent pas le cadeau automatiquement ; il est proposé par l’application 0.3.5.
