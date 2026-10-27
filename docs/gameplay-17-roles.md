# Gameplay des 17 rôles — multijoueur local

Les 17 cartes classiques sont sélectionnables dans le salon. Les rôles spéciaux
sont uniques ; Villageois et Loup-Garou peuvent être distribués plusieurs fois.
Les règles précises sont consultables au verso des cartes et dans le Codex.
Le serveur valide les phases, les cibles, les secrets et les usages des pouvoirs.

## Appels

Le MDJ choisit ses appels et décide du réveil. Les prérequis restent obligatoires :
Métamorphe puis Cupidon au début, Gardien avant la meute, attaque principale
avant Alpha, infection et Sorcière. La Sorcière attend aussi les modifications
de cette attaque. Un appel peut être passé. Les nouveaux appels sont affichés
à l'écran ; aucun nouvel enregistrement vocal n'est ajouté par cette mise à jour.

## Pouvoirs ajoutés

- **Métamorphe** : échange deux rôles vivants à la première nuit, lui-même compris.
  Les deux personnes reçoivent leur nouvelle carte en privé.
- **Cupidon** : lie deux vivants à la première nuit. La mort de l'un entraîne
  celle de l'autre. Deux amoureux de camps différents gagnent ensemble s'ils
  sont les deux derniers survivants.
- **Gardien** : protège des attaques de la meute et de l'Alpha, lui-même compris,
  sans protéger la même cible deux nuits consécutives. Ne bloque ni poison ni
  attaque personnelle du Loup Blanc.
- **Ancien** : résiste à la première attaque mortelle de la meute. Sa mort par
  vote, poison ou tir du Chasseur retire les pouvoirs du camp Village avant les
  réactions. Une mort par amour ne provoque pas cet effet.
- **Bouc émissaire** : meurt lors d'une égalité positive au vote, blanc compris.
  Zéro bulletin ne le condamne pas. Après sa mort au vote, choisit les personnes
  autorisées à voter le lendemain. Une sélection vide prive tout le monde du
  vote ; passer conserve les droits normaux.
- **Alpha** : choisit une seconde victime hors meute, distincte de la première.
  Exige une attaque principale ; perd ce pouvoir dès la première mort de la meute.
- **Loup Blanc** : participe à la meute, mais gagne seul comme dernier survivant.
  Attaque un autre loup pendant les nuits paires. Sa présence empêche une victoire
  collective des loups par majorité.
- **Père des Loups** : une fois, remplace la mort principale par une infection.
  La cible survivante rejoint la meute à la nuit suivante, conserve son pouvoir
  et adopte l'objectif des loups. La potion de vie annule l'infection, dont
  l'usage reste consommé. Le Gardien empêche cette attaque.
- **Idiot** : gracié et révélé lors de sa première condamnation au vote, perd
  définitivement son vote et conserve la parole. Peut mourir ensuite. La grâce
  ne fonctionne plus après la perte des pouvoirs du Village.
- **Joueur de Flûte** : charme deux autres vivants, ou un seul s'il ne reste
  qu'une cible. Gagne dès que tous les autres vivants sont charmés. Les charmés
  se reconnaissent en privé. Infecté, il adopte l'objectif de la meute.
- **Ange** : gagne s'il est directement condamné au premier vote. S'il survit
  sans gagner, devient Villageois. Une mort nocturne ou par amour ne suffit pas.
- **Petite Fille** : intercepte une fois un message déjà écrit pendant l'appel
  des loups, sans auteur. Une chance sur trois d'être signalée à la meute seule.
  Une tentative sans message est consommée. Ne reçoit ni les rôles ni la liste
  des loups. Infectée, elle utilise directement le chat de la meute.

## Résolution et vérification

Les morts nocturnes sont résolues à l'aube, puis les morts par amour et les
réactions du Bouc émissaire et du Chasseur. La victoire est évaluée après ces
réactions : Ange, partie nulle sans survivant, amoureux de camps différents,
Loup Blanc, Joueur de Flûte, Village, puis majorité des loups. Le Joueur de Flûte
peut aussi gagner immédiatement à la validation de son charme.
La roue reste narrative et ne saute aucune réaction en attente.

Les scénarios `expanded_roles_smoke.dart` vérifient les douze pouvoirs,
les secrets, les réactions et les objectifs. `expanded_network_smoke.dart`
connecte 17 clients WebSocket au serveur local. Les essais physiques sur les
téléphones restent à effectuer après compilation par le propriétaire.
