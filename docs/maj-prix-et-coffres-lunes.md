# Prix en Lunes d’or et coffres de défis

Les prix en monnaie virtuelle sont doublés, une seule fois pour les produits
existants au premier démarrage de cette mise à jour. Les prix personnalisés
suivent le même multiplicateur ; un prix absent reste absent. Les changements
ultérieurs de l’administrateur sont conservés aux redémarrages. Les montants en
argent réel ne sont pas modifiés.

Minimums : sticker 400, carte Intense 1 800, bordure 1 000 Lunes d’or.

Les 42 défis contiennent désormais des Lunes en plus des accessoires existants :

| Coffre | Lunes d’or |
| --- | --- |
| Classique | 15 |
| Épique | 25 à 50 |
| Premium | 80 à 150 |

Les fourchettes sont visibles dans le carnet et la présentation du coffre.
Le serveur tire le montant à la réclamation et le crédite dans la même
transaction que la récompense, avec un reçu unique par compte et défi. Le
montant exact remplace la fourchette après ouverture et le solde est actualisé.
Les coffres déjà réclamés ne sont pas rouverts. Un défi terminé mais pas encore
réclamé bénéficie du nouveau contenu.

Le cadeau du Créateur est valable à partir de 0.3.5 et pour les versions suivantes.
La nouvelle route `/coins/gifts/creator` et l’ancienne route utilisent le même
identifiant permanent `creator-0.3.5` : 100 Lunes au total par compte, même après
réinstallation, changement de version ou appels concurrents.

Déploiement : transférer le dépôt et redémarrer le backend pour les migrations.
La nouvelle application affiche la pièce dans les récompenses et le gain exact.
