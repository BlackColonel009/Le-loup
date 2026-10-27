# Intense Premium — gratuit pendant les tests

Dans **Habitants et préparation**, le MDJ choisit **Habillage du salon** :
Classique ou Intense Premium. Ce choix est diffusé à tous les joueurs et conservé
lors des reconnexions au salon. Il est fixé au lancement. Aucun achat ni compte
n'est nécessaire. Un changement avant lancement remet les joueurs non prêts.

Le pack applique la map hivernale v2, ses coordonnées propres, les maisons
jour/nuit/élimination, les seize illustrations Intense disponibles, le dos de
carte lunaire et la cérémonie d'élimination. Le Bouc émissaire utilise encore
son illustration Classique, avec verso Intense. Les pouvoirs et objectifs
restent ceux des dix-sept rôles communs. Horreur n'est pas encore sélectionnable
comme pack de salon.

## Roue modifiable

Le MDJ peut modifier les huit libellés avant lancement avec **Modifier les
sentences de la roue** : huit textes non vides, de 32 caractères maximum chacun.
Les libellés sont diffusés au salon puis utilisés par le tirage du serveur.
Les modifications sont propres au salon ; elles ne persistent pas après sa
fermeture. Aucune sentence ne modifie les rôles ni la résolution des morts.

Valeurs initiales : Guillotine, Pilori, Bannissement, Cachot, Échafaud, Exil,
Jugement et Gibet. Cette liste mêle exécutions et autres sentences narratives.
La roue Intense utilise une couronne illustrée fixe et huit secteurs dessinés
par l'application : les séparations correspondent aux huit résultats, et le
pointeur reste fixe pendant la rotation.

## Modifier les visuels

Les exports actifs sont dans `apps/le_loup/assets/village/intense/` : map.png,
house_day.png, house_night.png, house_eliminated.png, wheel.png, card_back.png,
card_clawed.png. Les sources restent dans `le_loup/Map/`.
Les coordonnées des parcelles sont dans `intenseVillagePlots`, dans
`apps/le_loup/lib/village/village_map.dart`. Les PNG des maisons se calent dans
le même cadre d'affichage sans modifier leurs pixels. La météo animée existante
reste superposée à la map ; les sons restent réservés au MDJ en local.
Les illustrations de rôles sont dans `assets/cards/intense/` ; les textes
sont partagés avec le Classique, sans second catalogue de pouvoirs.
La carte griffée complète apparaît au début de la révélation nocturne ; les
griffures animées transparentes restent celles déjà utilisées après retournement.

## Identité

Nom : Legende of Wolf. Crédit : by Logan R.D. Auteur : Roland DJAGBA Alias Logan.
Voir `apps/le_loup/AUTHOR.json` et `SIGNING.md` pour les mentions et l'état réel
de la signature de développement. Les icônes de lancement Android/iOS/Windows/Web
sont produites par `tools/update_app_icons.ps1`. Le logo transparent a été
détouré avec image_gen intégré ; l'original fourni est conservé.
