# Deck Classique — référence validée

Statut : règles convenues dans la conversation, non encore implémentées.
L'équilibrage et les compositions par nombre de joueurs restent à tester.

## Présentation et conduite

L'ambiance (Classique, Intense, Horreur) est indépendante des mécaniques.
Le pack du MDJ habille toute la salle. Le MDJ est dédié à l'animation.
Il déclenche les appels et les transitions. Tous voient le texte d'appel ;
seuls les joueurs autorisés reçoivent les commandes et informations privées.
En local, les appareils joueurs restent silencieux et le MDJ diffuse la musique.
À distance, le vocal est facultatif. Les canaux nocturnes sont limités aux rôles autorisés.
Le Codex public reste disponible avant et pendant la partie, sans attribution des rôles.

## Villageois

- Camp : Village.
- Action : débat et vote de jour, sans pouvoir nocturne.
- Aucun blocage spécial de parole en standard, sous réserve de la modération du MDJ.

## Loup-Garou

- Camp : Loups-Garous.
- Action : chaque nuit, la meute choisit une victime à l'unanimité.
- Tous les loups vivants doivent confirmer la même cible.
- Désaccord ou réponse manquante à l'échéance : aucune attaque mortelle de la meute.
- Le MDJ peut suspendre l'échéance en cas de problème de connexion.
- Le chat de meute et les identités des loups sont privés.

## Voyante

- Camp : Village ; agit avant les loups.
- Une consultation par nuit : rôle exact d'un joueur désigné.
- Le MDJ peut sélectionner « camp uniquement » avant la partie : cette option
  constitue une variante annoncée au Codex.
- Le résultat est privé à la Voyante et au MDJ.

## Sorcière

- Camp : Village ; agit après la décision des loups.
- Une potion de vie pour toute la partie : annule l'attaque des loups.
- Une potion de mort pour toute la partie : élimine un joueur désigné.
- Elle ne voit la victime des loups que tant que sa potion de vie est disponible.
- Elle peut se sauver elle-même en consommant cette potion.
- Elle peut utiliser les deux potions la même nuit.
- Les choix et les ressources restantes sont privés à la Sorcière et au MDJ.

## Chasseur

- Camp : Village ; tire à sa mort, quelle qu'en soit la cause.
- Cible : un autre joueur encore vivant.
- Mort nocturne : tir au réveil après l'annonce des morts nocturnes.
- Mort au vote : tir avant la nuit suivante.
- Le MDJ peut intervenir si aucune sélection n'arrive ; aucun tir automatique
  à l'échéance. Durée à définir avant l'implémentation.
- Les interactions avec les amoureux sont réservées à l'ajout futur de Cupidon.

## Résolution et victoire

1. Collecter et résoudre les actions nocturnes : Voyante, meute, Sorcière.
2. Appliquer les décès nocturnes, puis les annoncer au réveil.
3. Résoudre les tirs et toutes les réactions de mort.
4. Vérifier la victoire après la fin de ces réactions.

Village : aucun loup vivant. Loups : au moins autant de loups que d'autres
joueurs vivants. Aucun survivant : partie nulle, à vérifier avant les autres conditions.
Appliquer la même attente de fin des réactions après un vote de jour.

## Points à spécifier avant le moteur

- Vote du village : proposition précédente de vote blanc, choix modifiable
  jusqu'à la clôture et absence de vote distincte. Égalité et vote blanc en tête :
  proposition d'absence d'élimination, à confirmer.
- Délais, absences de réponse et cibles autorisées des pouvoirs hors Chasseur.
- Révélation publique des rôles des morts (non décidée).
- Composition minimale et nombre de loups adaptés à la taille du groupe.
