# La Soirée de Mère-grand — fonctionnement du jeu

Document de conception du 3 novembre 2026, pour Mordeviel Legendary, par Roland DJAGBA, alias Logan.

Ce document décrit un jeu à part entière de poursuite et de déduction sociale, avec des personnages chibi 3D contrôlés directement. Il constitue la base de conception avant son développement. Les règles convenues sont distinguées ci-dessous des propositions nécessaires pour préparer une première version jouable. Les réglages chiffrés restent à tester.

## 1. Le principe

Un salon accueille jusqu’à **20 joueurs**, avec un maître du jeu qui organise la partie et choisit notamment le nombre de Loups. La présentation du jeu est en paysage.

Au départ, tous les participants ont l’apparence de **Rubine**, notre Chaperon rouge. Certains appartiennent secrètement au camp des Loups. Pendant la nuit, ces derniers prennent leur forme de Loup et poursuivent les joueurs du village.

Les villageois explorent la carte avec une torche, accomplissent des tâches, cherchent des objets et utilisent des cachettes. Certains objets leur permettent de devenir temporairement **Pèlerine**, la Mère-grand, pour chasser les Loups.

Le jour, les survivants discutent et votent pour éliminer un suspect. Le village cherche à éliminer tous les Loups ; les Loups cherchent à éliminer tous les villageois.

L’ambiance mélange suspense nocturne, conte fantastique et humour cartoon. Les bagarres utilisent des nuages de poussière, des étoiles et des mouvements exagérés. La dévoration laisse des os et une âme qui s’échappe, sans nécessiter un traitement réaliste du gore.

## 2. Les personnages et les camps

| Forme | Camp et fonction | Particularité |
|---|---|---|
| **Rubine** | Forme des joueurs du village et apparence commune de départ | Torche, exploration, tâches, objets et cachettes |
| **Le Loup** | Camp secret des Loups | Transformation nocturne, déplacement à quatre pattes et vision nocturne monochrome |
| **Pèlerine** | Transformation temporaire d’une Rubine ; reste dans le camp du village | Canne ou marteau, permettant d’éliminer un Loup attrapé |

Pèlerine n’est donc pas un troisième camp ni une identité attribuée définitivement à un joueur.

**Proposition de présentation :** les Loups reprennent l’apparence de Rubine pendant le jour. Lorsqu’un Loup est visible la nuit, son pseudo n’est pas affiché automatiquement aux villageois. Voir une créature ne révèle donc pas directement quel participant l’incarne. Le MDJ conserve cette correspondance dans sa vue privée.

## 3. Avant de jouer

Le parcours proposé est le suivant :

1. Ouvrir l’espace La Soirée de Mère-grand.
2. Passer à l’interface paysage.
3. Consulter ses personnages et choisir leurs apparences.
4. Créer ou rejoindre un salon.
5. Choisir son pseudo de partie et se déclarer prêt.
6. Attendre le lancement par le MDJ.

Le choix d’apparence ne choisit pas le camp du joueur. Il prépare les skins utilisés pour ses différentes formes. Dans le salon public de préparation, chacun apparaît en Rubine pour préserver les identités.

Les modèles 3D et leurs skins sont destinés à des packs téléchargeables. Le téléchargement et l’accès à un skin sont deux informations distinctes. Le système doit vérifier les ressources nécessaires avant le lancement.

Les contrôles doivent rester accessibles aux écrans tactiles ; une adaptation clavier/manette pourra être prévue sans modifier les règles.

## 4. Préparation par le maître du jeu

Le MDJ configure la carte, le nombre de Loups, les durées des phases et les options de partie. L’attribution des camps peut être aléatoire ; une attribution manuelle privée est une option proposée pour les tests.

Pour une première version, le MDJ pilote les débuts de nuit, les levers du jour, les débats et les votes. Les poursuites, captures et coups restent des actions réalisées par les joueurs.

Le MDJ dispose d’une vue d’observation : participants, camps, connexions, phase, incidents et journal privé. Ses informations ne sont pas affichées aux joueurs.

**Convention proposée :** le MDJ est observateur et n’occupe pas l’une des 20 places de joueurs. Le minimum de participants et les limites du nombre de Loups restent à équilibrer.

## 5. Déroulement d’une manche

### Installation

Les joueurs apparaissent en Rubine. Une courte présentation explique leurs commandes. Chaque participant reçoit uniquement les informations autorisées pour son camp. Les positions de départ doivent laisser une distance raisonnable entre les joueurs ; aucun Loup ne doit commencer directement au contact d’une victime.

### La nuit

Les Loups prennent leur forme nocturne. Les villageois peuvent explorer, accomplir des tâches, trouver des objets, se cacher ou activer une transformation en Pèlerine. Les Loups cherchent des victimes et doivent fuir les Pèlerine capables de les frapper.

La caméra suit le personnage. La carte visible à l’écran adopte l’éclairage autorisé pour celui-ci : couleur sombre et torche pour Rubine, vision monochrome pour le Loup. Cette vision ne révèle pas les joueurs cachés.

### Le passage au jour

**Proposition :** un compte à rebours partagé de cinq secondes annonce le changement. À son terme, les captures et attaques cessent, les actions déjà validées sont résolues, puis les survivants passent au conseil.

Les Loups retrouvent leur apparence de Rubine. Pour la première version proposée, une transformation active en Pèlerine s’arrête à l’aube ; les objets non utilisés restent dans l’inventaire. Ce réglage doit être annoncé avant la partie.

### Le conseil et le vote

Les vivants débattent, confrontent les appels à l’aide, les emplacements des os et leurs observations. Le MDJ ouvre ensuite un vote chronométré.

Après la résolution du vote et la vérification de victoire, une nouvelle nuit peut commencer.

## 6. Rubine : explorer et survivre

Rubine se déplace dans le décor avec les commandes tactiles. Sa torche lui permet de repérer les chemins, objets, tâches et cachettes dans les zones sombres. Elle voit en couleur.

Commandes proposées :

- Joystick de déplacement à gauche.
- Bouton d’interaction à droite.
- Bouton de cachette lorsqu’un abri est à portée.
- Emplacement d’objet utilisable.
- Commande de torche, avec extinction automatique dans une cachette.

Les actions contextuelles doivent être nommées clairement : **Se cacher**, **Sortir**, **Ramasser**, **Examiner**, **Utiliser l’objet**. Le joueur doit comprendre la portée et la disponibilité d’une action sans deviner quel élément toucher.

## 7. Les cachettes

Les cartes comportent des cachettes : buissons, armoires, passages derrière des rideaux, dessous de lits ou abris adaptés au décor.

**Règle convenue : une Rubine installée dans une cachette valide n’est pas visible par le Loup**, même avec sa vision nocturne. Son pseudo, son portrait et un éventuel marqueur de position ne doivent pas la trahir.

L’entrée et la sortie utilisent une courte animation. Le joueur conserve un bouton de sortie accessible. Une place occupée ne doit pas se superposer physiquement avec un autre personnage.

**Réglage proposé à tester :** une place par petite cachette, avec un temps de présence limité et un délai avant de réutiliser le même abri. Cela empêche de rester protégé indéfiniment. La possibilité pour un Loup de fouiller une cachette n’est pas une règle validée ; elle devra être discutée séparément.

La vision monochrome ne doit jamais devenir une détection automatique d’occupants.

## 8. Le Loup : poursuivre et capturer

Le Loup court à quatre pattes et observe la nuit en noir et blanc. Il peut profiter des chemins, des angles de vue et des mouvements aperçus pour suivre une Rubine.

**Propositions de contrôle :** déplacement, course courte et attaque à portée limitée. Le Loup doit atteindre sa victime ; il ne peut pas déclencher une dévoration à distance à travers un mur ou une cachette.

Une capture confirmée déclenche la séquence suivante :

1. Un message automatique **HELP** paraît dans le chat avec le pseudo de la victime et la zone de l’attaque.
2. La dévoration est présentée par une courte animation.
3. Le corps disparaît et un tas d’os reste sur place.
4. L’âme de la victime s’élève et devient un fantôme spectateur.

Exemple : **🆘 HELP — Lina appelle à l’aide près du vieux moulin !**

Le message ne nomme pas le Loup. Il provient du jeu et ne dépend pas de la saisie de la victime. Une capture confirmée correspond à une élimination ; aucune résurrection n’est incluse dans les règles actuelles de ce mode.

## 9. Pèlerine : renverser la poursuite

Une Rubine obtient un objet permettant de devenir temporairement Pèlerine. L’objet détermine sa durée et l’équipement reçu : canne ou marteau.

Le déroulement est le suivant :

1. La Rubine trouve ou gagne l’objet pendant la partie.
2. Elle l’active au moment choisi.
3. Une animation de transformation fait apparaître Pèlerine et son arme.
4. Une jauge indique au joueur le temps restant.
5. Pèlerine poursuit le Loup et peut l’éliminer lorsqu’elle l’attrape avec son coup.
6. À l’expiration, le personnage redevient Rubine.

La confrontation produit un nuage de bagarre cartoon, accompagné d’étoiles et d’un son de coup exagéré. Le Loup éliminé quitte les interactions de la partie.

**Propositions d’équilibrage :**

- Un court mouvement de préparation rend le coup lisible et esquivable.
- La canne favorise l’agilité et le marteau une portée de frappe plus confortable ; les valeurs restent à tester.
- Pèlerine est une forme protectrice temporaire que le Loup doit éviter. L’étendue exacte de sa protection contre une attaque doit être fixée avant le développement des combats.
- Une Pèlerine ne peut pas éliminer un villageois avec son arme.
- Les objets de transformation sont limités pour conserver le danger des Loups.

Les équipements de partie sont distincts des skins : le pouvoir vient de l’objet gagné en jeu.

## 10. Les tâches et les objets

Les tâches encouragent l’exploration et la prise de risque. Elles peuvent fournir des objets ou des fragments nécessaires à une transformation.

**Exemples proposés :** réparer une lanterne, retrouver une clé, ouvrir un coffre, récupérer des ingrédients ou réparer un mécanisme dans une remise.

Une tâche doit être courte, compréhensible sur téléphone et interrompable. Un joueur en train d’agir doit pouvoir percevoir l’arrivée d’un danger et reprendre le contrôle.

Les objets de transformation peuvent être présentés comme un châle enchanté ou un objet associé à Pèlerine. Leur nom définitif et les conditions d’obtention restent à choisir.

Dans les conditions de victoire convenues, accomplir les tâches n’offre pas une victoire automatique. Elles servent à obtenir des moyens de survie et de chasse.

## 11. Les os et les indices

Les os restent à l’endroit de la dévoration. Ils témoignent d’une élimination et peuvent être retrouvés pendant l’exploration.

**Proposition d’interaction :** un bouton Examiner affiche le pseudo de la victime et la zone. Il ne révèle pas l’identité du tueur. Les appels à l’aide restent consultables dans le journal de la manche pour alimenter le débat.

Le signalement des os ne déclenche pas automatiquement un vote dans les règles actuellement établies. Pour la première version proposée, le MDJ conserve la main sur le passage au conseil.

## 12. Les fantômes

Après la dévoration, l’âme de Rubine devient un fantôme qui plane dans le décor et peut se déplacer pour observer.

**Règles convenues :**

- Le fantôme peut identifier le Loup responsable de son élimination.
- Il est visible uniquement par les autres joueurs éliminés.
- Il ne peut communiquer avec les vivants par le chat ou le vocal.
- Il ne vote pas et ne participe plus aux actions de jeu.

La révélation de l’identité de tous les Loups, au-delà du tueur observé, n’est pas encore fixée.

Le mode spectateur ne doit permettre ni collision avec les vivants, ni interaction avec les objets, ni émission de signal révélant le tueur. Les stickers, marqueurs et mouvements visibles ne doivent pas devenir un moyen détourné de communiquer avec les vivants.

**Proposition d’uniformité :** les joueurs éliminés au vote ou en forme de Loup bénéficient également d’un mode fantôme spectateur. Les droits d’observation précis restent à régler ; leurs actions sur la partie restent désactivées.

## 13. Discussion et vote

Pendant le jour, les joueurs vivants peuvent discuter et voter. Le MDJ règle le temps de débat et celui du scrutin.

**Règles de vote proposées pour la première version :**

- Une voix par joueur vivant.
- Choix d’un suspect ou vote blanc.
- Le dernier choix confirmé avant la clôture fait foi.
- La personne ayant le plus de suffrages est éliminée.
- Une égalité en tête ne provoque aucune élimination.
- Si le vote blanc arrive seul en tête, personne n’est éliminé.
- Un joueur qui ne vote pas est considéré comme abstentionniste.
- Le MDJ et les fantômes ne votent pas.

La révélation publique du camp du joueur exécuté est un réglage proposé à confirmer. La mise en scène doit rester dans l’univers cartoon du mode.

La nuit, les alertes automatiques HELP restent disponibles. Les échanges libres et l’éventuel canal privé de la meute devront être définis avec les options du MDJ. Les fantômes n’ont aucun canal permettant de joindre les vivants.

## 14. Conditions de victoire

**Le village gagne lorsque tous les Loups sont éliminés**, par les actions de Pèlerine ou par les votes.

**Les Loups gagnent lorsqu’il ne reste aucun joueur vivant du village.** Une Rubine transformée en Pèlerine compte toujours comme un membre vivant du village.

Il n’existe pas de victoire automatique des Loups à égalité numérique dans les règles retenues : un villageois encore vivant peut continuer à se défendre et à obtenir une transformation.

**Proposition de résolution :** terminer les actions déjà confirmées avant d’annoncer le résultat. Si une future interaction permet l’élimination simultanée des derniers membres des deux camps, annoncer une partie nulle. Ce cas devra être couvert lors du développement.

L’écran final présente le camp gagnant, les identités et les événements marquants. Les statistiques et défis propres à ce mode devront être définis séparément de ceux des parties de cartes.

## 15. Première carte proposée : le domaine de Pèlerine

La carte peut réunir quatre zones reliées :

| Zone | Intérêt de jeu | Exemples d’éléments |
|---|---|---|
| Maison de Pèlerine | Tâches et poursuites à courte distance | Entrées opposées, cuisine, armoire, dessous de lit |
| Jardin | Zone de transition et d’observation | Buissons, cabanon, tonneaux, potager |
| Forêt | Trajets alternatifs et ambiance nocturne | Arbres, rochers, troncs creux, passages sinueux |
| Clairière et vieux moulin | Points d’intérêt attirant les joueurs | Coffre, mécanisme à réparer, chemins de fuite |

Les zones doivent porter des noms courts, réutilisés dans les messages HELP. Les chemins principaux et les issues doivent rester lisibles en couleur comme en noir et blanc.

La carte doit offrir des possibilités de fuite et éviter les points de départ sans issue. Sa taille et le nombre de cachettes doivent être adaptés au nombre de participants. Les cachettes sont positionnées comme des éléments de jeu explicites, avec des interactions cohérentes.

## 16. Interface et retour visuel

- En haut : phase, manche, temps restant, accès au journal et aux réglages autorisés.
- À gauche : joystick.
- À droite : boutons contextuels et objet équipé.
- À proximité du personnage contrôlé : états importants et durée de Pèlerine.
- Dans le chat : HELP, événements publics et discussion selon la phase.
- Pour un fantôme : indication claire Spectateur et commandes d’observation.
- Pour le MDJ : commandes de phase et vue privée séparées des contrôles des joueurs.

Les alertes de transition doivent rester visibles lorsqu’un joueur consulte le journal. Les changements importants utilisent un retour visuel et sonore, tout en respectant les réglages de son et de réduction des animations.

## 17. Présentation 3D et sons

Les personnages partagent une direction artistique chibi : grosses têtes, corps compacts, silhouettes faciles à distinguer et mouvements expressifs.

Rubine utilise des couleurs chaleureuses centrées sur le rouge. Pèlerine est immédiatement identifiable par sa silhouette de grand-mère et son arme. Le Loup conserve une silhouette quadrupède, avec un museau, des oreilles et une queue lisibles dans l’obscurité.

Le travail sonore proposé comporte des pas, du vent, des feuillages, des interactions, la torche, les transformations, le HELP, la dévoration stylisée et la bagarre de Pèlerine. Les sons doivent informer le joueur sans révéler automatiquement une identité secrète.

Les images de référence 3D ne sont pas encore des personnages jouables. Il faudra des modèles, leurs textures, leurs squelettes et les animations décrites dans le document de prompts.

## 18. Réglages de départ proposés à tester

| Réglage | Première valeur proposée |
|---|---|
| Joueurs | 4 à 20, minimum à confirmer |
| Loups | Environ un Loup pour cinq joueurs, avec un minimum d’un |
| Nuit | 150 secondes |
| Débat | 90 secondes |
| Vote | 30 secondes |
| Avertissement avant changement de phase | 5 secondes |
| Pèlerine avec canne | 15 secondes |
| Pèlerine avec marteau | 20 secondes |
| Cachette | 25 secondes maximum, puis délai de réutilisation |
| Objets de transformation équipés | Un emplacement par villageois |
| Transformations simultanées | À limiter selon le nombre de Loups ; valeur à tester |

Ces valeurs ne sont pas des règles déjà validées. Elles servent à lancer les essais d’équilibrage. La puissance exacte de la protection de Pèlerine, les attaques, l’esquive et les délais des pouvoirs devront être testés ensemble.

## 19. Règles de fiabilité pour le développement

Le serveur de partie devra valider les captures, les distances d’interaction, les murs, l’occupation des cachettes, les objets, les transformations, les votes et les victoires.

Les informations secrètes ne doivent pas être transmises à un joueur non autorisé. Une Rubine cachée ne doit pas réapparaître par un portrait, un marqueur ou une position exposée au Loup. Les fantômes et leur communication doivent être isolés des vivants.

Le chronomètre d’une transformation appartient à la partie, pas au téléphone : mettre l’application en arrière-plan ne doit pas prolonger un pouvoir. Les règles de reconnexion sont à définir ; une courte période de reprise avec un personnage encore présent dans le monde est proposée. Le MDJ peut disposer d’une pause globale.

Les commandes du MDJ et les messages système doivent être authentifiés. Les nouveaux événements de ce jeu ne doivent pas être confondus avec les événements des anciennes parties de cartes.

Le choix du moteur 3D, de son intégration dans Mordeviel et du serveur de déplacement est une prochaine décision technique. Ce document ne suppose pas que le moteur actuel des cartes gère déjà les mouvements 3D.

## 20. Décisions restant à finaliser

1. Minimum de participants et nombre maximal de Loups autorisé.
2. Durée des manches, transformations et cachettes.
3. Protection exacte de Pèlerine et règles de frappe/esquive.
4. Conditions précises pour gagner les objets de transformation.
5. Révélation du camp après le vote.
6. Informations visibles par les fantômes autres que l’identité de leur agresseur.
7. Fonctionnement des communications nocturnes.
8. Reconnexion et pause de partie.
9. Moteur 3D et intégration technique.

Les noms retenus sont **Pèlerine**, **Rubine** et **le Loup**. Les règles, les modèles et les skins doivent conserver ces appellations.
