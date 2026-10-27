# Deck Classique — référence validée

Statut : rôles, distribution et première nuit implémentés dans le serveur local.
Le débat, le vote et la boucle jour/nuit sont également implémentés en LAN.
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
  à l'échéance. Le prototype propose 60 secondes, avec pause possible par le MDJ.
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

- Les compositions recommandées et l'équilibrage par nombre de joueurs restent à tester.
- Délais, absences de réponse et cibles autorisées des pouvoirs hors Chasseur.
- L'équilibrage des parties avec ou sans révélation des rôles reste à tester.
- Composition minimale et nombre de loups adaptés à la taille du groupe.

## Conventions de la première nuit du prototype

- Actions chronométrées : 60/120/180 secondes par appel (choix MDJ), 60 pour le Chasseur.
- À l'échéance, l'appel se ferme sans avancer automatiquement ; le MDJ garde la main.
- Action manquante : pas de vision, pas de potion et pas de tir automatique.
- La meute peut modifier son choix jusqu'à clôture. Les autres pouvoirs sont
  confirmés une fois par appel. Une vision cible un autre joueur vivant ; la
  meute ne peut pas viser un loup ; une potion de mort peut viser tout survivant.
- Le MDJ choisit avant la partie si les cartes sont révélées à l'élimination
  (activé par défaut dans l'expérience visuelle). En mode secret, les autres
  joueurs voient un dos de carte ; le tir du Chasseur révèle de fait son rôle.
  Toutes les cartes sont révélées à la fin.
- Les rôles configurés sont appelés même s'ils ont été éliminés, sans leur donner d'action.

## Vote de jour du prototype

Tous les survivants peuvent voter pour un survivant ou voter blanc. Le choix
peut être modifié jusqu'à la clôture ; un seul bulletin par joueur est compté.
Une absence de bulletin est une abstention, même en cas de déconnexion.
Le scrutin est secret jusqu'à clôture. Ensuite seuls les totaux sont publics,
pas l'identité des votants. La cible seule en tête est éliminée ; une égalité,
y compris avec le blanc, le blanc seul en tête ou zéro bulletin n'éliminent personne.
Le tir du Chasseur est résolu avant la victoire et la nuit suivante.
Le MDJ contrôle la discussion générale et l'ouverture du scrutin, sa pause,
sa clôture et le passage à la nuit. Le serveur refuse de sauter le vote pour
relancer directement une nuit depuis le débat.

## Cérémonies visuelles

La sentence tirée à la roue après une élimination de jour est purement narrative.
Elle ne change pas le résultat du vote et n'ajoute aucun pouvoir ou décès.
Le MDJ peut la lancer une fois par élimination au vote. Les griffures servent
à annoncer les morts nocturnes, sans distinguer publiquement les causes précises.


## Choix des appels nocturnes par le MDJ

Le moteur ne passe plus automatiquement de la Voyante aux Loups puis à la
Sorcière. Après l’endormissement, le MDJ choisit un appel dans la liste privée
des rôles actifs encore vivants. Il termine cet appel, revient à la liste et
choisit le suivant. Chaque rôle ne dispose que d’un appel par nuit.

La Voyante peut être appelée avant ou après la meute, et après la Sorcière.
L’appel de la Sorcière attend la résolution de l’attaque des loups afin de lui
montrer la bonne victime ; ce prérequis est expliqué dans l’interface.
Le Chasseur reste une réaction déclenchée par sa mort, pas un appel de routine.

Le réveil du village est une décision explicite du MDJ. Si certains appels
n’ont pas été utilisés, une confirmation rappelle que leurs actions sont
ignorées cette nuit. Les morts sont résolues à l’aube, comme auparavant.
Les actions terminées sont remises à zéro à chaque nouvelle nuit. Les joueurs
n’ont pas accès à la liste privée des appels du MDJ. Le retour à cette liste
ne rejoue pas l’annonce d’endormissement.

## Extension jouable

Les exceptions des nouveaux rôles (Bouc émissaire, Idiot, amoureux et objectifs solitaires) sont décrites dans [les règles des 17 rôles](gameplay-17-roles.md). Le Bouc émissaire dispose aussi d'une réaction après sa mort, avant la suite de la partie.
