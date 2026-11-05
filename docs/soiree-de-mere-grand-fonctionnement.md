# La Soirée de Mère-grand — fonctionnement du jeu

Document de conception du 3 novembre 2026, pour Mordeviel Legendary, par Roland DJAGBA, alias Logan.

Mis à jour le 5 novembre 2026 : capuche enchantée, boosts, pièces de bronze, points de vie, Lance de canne et Loup Alpha. Ces règles remplacent les anciennes propositions de capture mortelle en un coup et de protection de Pèlerine à déterminer. Le mode reste au stade de conception.

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
| **Rubine** | Forme des joueurs du village et apparence commune de départ | Trois cœurs, capuche enchantée, boost d’invisibilité de 10 secondes, torche et survie |
| **Le Loup** | Camp secret des Loups | Trois cœurs, déplacement à quatre pattes, vision nocturne monochrome et boost temporaire Loup Alpha |
| **Pèlerine** | Transformation temporaire d’une Rubine ; reste dans le camp du village | Cœurs en acier, invulnérabilité aux attaques, canne ou marteau et compétence Lance de canne |

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
7. Après le lancement, consulter la vue d’ensemble de la carte et choisir son emplacement de départ.

Le choix d’apparence ne choisit pas le camp du joueur. Il prépare les skins utilisés pour ses différentes formes. Dans le salon public de préparation, chacun apparaît en Rubine pour préserver les identités.

Les modèles 3D et leurs skins sont destinés à des packs téléchargeables. Le téléchargement et l’accès à un skin sont deux informations distinctes. Le système doit vérifier les ressources nécessaires avant le lancement.

Les contrôles doivent rester accessibles aux écrans tactiles ; une adaptation clavier/manette pourra être prévue sans modifier les règles.

## 4. Préparation par le maître du jeu

Le MDJ configure la carte, le nombre de Loups, les durées des phases et les options de partie. L’attribution des camps peut être aléatoire ; une attribution manuelle privée est une option proposée pour les tests.

Pour une première version, le MDJ pilote les débuts de nuit, les levers du jour, les débats et les votes. Les poursuites, captures et coups restent des actions réalisées par les joueurs.

Le MDJ dispose d’une vue d’observation : participants, camps, connexions, phase, incidents et journal privé. Ses informations ne sont pas affichées aux joueurs.

**Convention proposée :** le MDJ est observateur et n’occupe pas l’une des 20 places de joueurs. Le minimum de participants et les limites du nombre de Loups restent à équilibrer.

## 5. Déroulement d’une manche

### Placement sur la carte après le lancement

**Règle ajoutée le 5 novembre 2026 :** lorsque le créateur du salon lance le jeu, les joueurs accèdent à une **vue d’ensemble de la carte** et **choisissent l’endroit où ils souhaitent commencer**. Cette phase précède le début des déplacements et des poursuites. Ils peuvent se disperser ou choisir de se regrouper.

Le parcours est : **lancement par le créateur → vue de la carte → choix des emplacements → téléportation des joueurs aux endroits choisis → début de la partie**.

**Plusieurs joueurs peuvent choisir le même endroit : ils y sont simplement téléportés ensemble.** Aucun emplacement n’est réservé à une seule personne et aucun choix partagé n’est rejeté ou redistribué. Plus les joueurs sont regroupés, plus ils constituent des proies faciles, mais plus ils ont aussi l’occasion de travailler ensemble pour réussir. Ce compromis fait partie de leur choix tactique.

Le serveur devra valider que l’endroit choisi est praticable, à l’intérieur de la carte et hors des murs. Cette validation ne doit pas imposer de séparation entre joueurs ni empêcher leur arrivée groupée. La gestion visuelle et physique des personnages au même point reste un détail technique à régler sans modifier leur destination commune.

**Modalités restant à définir :** choix libre sur les zones autorisées ou sélection de points prédéfinis, visibilité des choix des autres joueurs, confirmation du placement, durée de cette phase et solution pour un joueur qui ne choisit pas. Ces modalités doivent préserver les identités secrètes. Les choix identiques sont autorisés et ne constituent pas un conflit à résoudre.

### Installation

Les joueurs apparaissent en Rubine à l’emplacement choisi et validé. Une courte présentation explique leurs commandes. Chaque participant reçoit uniquement les informations autorisées pour son camp.

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

**Règles ajoutées le 5 novembre :** Rubine possède **trois cœurs de vie**. Une attaque simple du Loup lui retire **un cœur** ; une attaque du Loup Alpha lui retire **deux cœurs**. Elle est éliminée lorsque ses cœurs sont épuisés.

Sa **capuche est enchantée**. Elle peut trouver pendant le jeu un **boost de capuche** qu’elle active pour devenir **invisible aux yeux des Loups pendant 10 secondes**. Ce boost pourra également être acheté dans la future boutique de boosts de La Soirée de Mère-grand.

L’invisibilité concerne sa détection visuelle par les Loups : son pseudo, son portrait, sa torche et les marqueurs ne doivent pas dévoiler sa position. Elle n’accorde pas, à elle seule, une invulnérabilité. Les interactions avec les collisions, les sons, les attaques et le Loup Alpha restent à préciser.

### Pièges de Rubine

Les pièges servent d’abord à **retarder le Loup**. Les types retenus sont :

| Piège | Effet ou présentation retenue |
|---|---|
| Pièges de bois et barrages d’épines | Obstacles pour retarder sa progression |
| Trous d’épines | Pièges au sol pour retarder le Loup |
| Plantes sauvages | Entraves ; comportement précis à définir |
| Bain glacé | Gèle temporairement l’ennemi |
| Bain chaud | Fait fuir l’ennemi en criant |
| Frigo piégé dans une maison | Enferme le Loup ; appuis rapides sur la touche d’attaque pour s’en libérer. En cas d’échec, sortie dans un glaçon et perte d’un cœur |

Le Loup possède une **immunité toute-puissante aux pièges**, au sens où leur effet principal est de le retarder plutôt que de lui infliger des dégâts à chaque déclenchement. **S’il subit trois pièges différents, il perd un demi-cœur.** Cette précision remplace la règle précédente des trois passages dans le même piège. La remise à zéro du compteur après ces dégâts reste à préciser.

**Exception explicite :** l’échec de libération du frigo piégé inflige directement **un cœur** de dégâts, selon la règle particulière décrite ci-dessous. Le cumul éventuel avec le demi-cœur après trois pièges différents reste à décider.

### Piège du frigo : enfermer le Loup

Rubine peut préparer **un piège dans une maison pour pousser le Loup dans le frigo**. Le mécanisme exact de déclenchement et de poussée reste à concevoir.

1. Le piège pousse le Loup dans le frigo.
2. Le joueur incarnant le Loup doit **atteindre 20 combos, soit 20 appuis rapides sur la touche d’attaque, avant la fin des 5 secondes**. Une **jauge circulaire** se vide pendant cette épreuve et un compteur indique la progression vers 20.
3. Dès que le compteur atteint **20 avant l’expiration**, le Loup se libère ; aucune pénalité de gel ou de vie en cas de réussite n’est fixée. Le seuil retenu est bien 20 appuis, sans exiger un vingt-et-unième.
4. **Si le seuil n’est pas atteint à temps, il sort gelé dans un glaçon pendant 5 secondes et perd un cœur de vie.**

La jauge circulaire de libération représente les **5 secondes disponibles**, et reste distincte de la jauge de résistance du piège. La relation entre les appuis de libération et cette résistance reste à préciser, ainsi que le comportement du Loup Alpha face à ce piège particulier. Ce frigo piégé est distinct du bain glacé.

Chaque piège possède une **jauge de résistance**. Si le joueur incarnant le Loup repère le piège, il peut l’attaquer pour vider cette jauge. **À résistance nulle, le piège disparaît.** L’attaque contre un piège et le fait d’en subir l’effet sont deux événements distincts ; une attaque ne compte pas automatiquement comme un déclenchement subi.

La pose, l’obtention, la durée des effets, la résistance de chaque type et les dégâts infligés aux pièges restent à définir. L’articulation du compteur de trois déclenchements avec le franchissement par le Loup Alpha reste également à préciser.

Commandes proposées :

- Joystick de déplacement à gauche.
- Bouton d’interaction à droite.
- Bouton de cachette lorsqu’un abri est à portée.
- Emplacement d’objet utilisable.
- Commande de torche, avec extinction automatique dans une cachette.

Les actions contextuelles doivent être nommées clairement : **Se cacher**, **Sortir**, **Ramasser**, **Examiner**, **Utiliser l’objet**. Le joueur doit comprendre la portée et la disponibilité d’une action sans deviner quel élément toucher.

## 7. Les cachettes

Les cartes comportent de nombreuses cachettes adaptées au décor. La liste inclut désormais explicitement les ajouts du 5 novembre 2026 :

- **Dans les bâtiments :** armoires, frigos, dessous de tables, dessous de draps, passages derrière des rideaux et dessous de lits.
- **Au sous-sol :** un sous-sol accessible dans la maison de Pèlerine, avec des emplacements de cachette à aménager. Le sous-sol est une zone de la carte ; ses abris utilisables doivent être identifiés explicitement.
- **À l’extérieur :** buissons, tonneaux et troncs creux, ainsi que des abris adaptés aux autres décors.

Les frigos sont des accessoires de conte cartoon conçus comme cachettes de jeu, mais présentent aussi un danger de gel. Chaque type demande une entrée, une attente et une sortie adaptées : ouvrir puis refermer une armoire ou un frigo, se glisser sous une table, un lit ou un drap, ou rejoindre un abri extérieur. La répartition exacte et le nombre d’emplacements de chaque carte restent à réaliser dans le moteur 3D.

### Cachettes dangereuses : le froid du frigo

Certaines cachettes présentent un danger pour Rubine. **Lorsqu’elle se cache dans un frigo, Rubine subit un effet de gel et perd lentement ses points de vie.** La protection contre la vue du Loup ne supprime pas ce danger. Le joueur conserve un bouton pour sortir de la cachette.

Le délai avant le premier dégât, la fréquence et la quantité de vie perdue, ainsi que la persistance éventuelle du froid après la sortie restent à définir. Aucun dégât chiffré ni soin automatique à la sortie n’est établi. Les autres cachettes dangereuses et leurs effets pourront être précisés séparément.

**Règle convenue : une Rubine installée dans une cachette valide n’est pas visible par le Loup**, même avec sa vision nocturne. Son pseudo, son portrait et un éventuel marqueur de position ne doivent pas la trahir.

L’entrée et la sortie utilisent une courte animation. Le joueur conserve un bouton de sortie accessible. Une place occupée ne doit pas se superposer physiquement avec un autre personnage.

**Réglage proposé à tester :** une place par petite cachette, avec un temps de présence limité et un délai avant de réutiliser le même abri. Cela empêche de rester protégé indéfiniment. La possibilité pour un Loup de fouiller une cachette n’est pas une règle validée ; elle devra être discutée séparément.

La vision monochrome ne doit jamais devenir une détection automatique d’occupants.

## 8. Le Loup : poursuivre et capturer

Le Loup court à quatre pattes et observe la nuit en noir et blanc. Il peut profiter des chemins, des angles de vue et des mouvements aperçus pour suivre une Rubine.

**Propositions de contrôle :** déplacement, course courte et attaque à portée limitée. Le Loup doit atteindre sa victime ; il ne peut pas déclencher une dévoration à distance à travers un mur ou une cachette.

**Vie et dégâts convenus :** le Loup possède **trois cœurs**, affichables en demi-cœurs. Chaque coup ordinaire de Pèlerine lui retire **un demi-cœur** ; sa Lance de canne lui retire **un cœur et demi** si elle le touche. Le Loup est éliminé lorsque ses cœurs sont épuisés. À pleine vie, cela représente six coups ordinaires ou deux Lances de canne réussies, sans soin ni autre effet.

### Boost Loup Alpha

Le Loup peut récupérer un bonus **Loup Alpha** pendant le jeu ou l’acheter dans la future boutique. Ce boost dure **20 secondes**. Il ne constitue pas un nouveau camp.

Pendant son effet, ses attaques retirent **deux cœurs à Rubine**, contre un normalement. Il peut également **escalader ou traverser tous les pièges de Rubine**. Cette capacité ne lui donne pas automatiquement le droit de traverser les murs, de voir les joueurs cachés ou invisibles, ni de blesser Pèlerine.

Quand une attaque épuise les cœurs de Rubine, son élimination confirmée déclenche la séquence suivante :

1. Un message automatique **HELP** paraît dans le chat avec le pseudo de la victime et la zone de l’attaque.
2. La dévoration est présentée par une courte animation.
3. Le corps disparaît et un tas d’os reste sur place.
4. L’âme de la victime s’élève et devient un fantôme spectateur.

Exemple : **🆘 HELP — Lina appelle à l’aide près du vieux moulin !**

Le message ne nomme pas le Loup. Il provient du jeu et ne dépend pas de la saisie de la victime. Un coup non mortel ne provoque pas la dévoration : Rubine reste en jeu avec ses cœurs restants. Le déclenchement éventuel d’un HELP dès la première blessure reste à décider. Aucune résurrection n’est incluse dans les règles actuelles de ce mode.

## 9. Pèlerine : renverser la poursuite

Une Rubine obtient un objet permettant de devenir temporairement Pèlerine, avec une canne ou un marteau. La transformation s’accompagne de la phrase **« Sauve-moi, Pèlerine ! »**. La forme de Mère-grand dure **10 secondes**, et **15 secondes dans certains cas selon le compte**. Les critères liés au compte seront définis plus tard. Ces durées concernent le temps passé en Pèlerine, pas une attente de dix secondes avant de pouvoir la contrôler ; cette lecture est à confirmer si nécessaire.

Le déroulement est le suivant :

1. La Rubine trouve ou gagne l’objet pendant la partie.
2. Elle l’active au moment choisi.
3. Une animation de transformation fait apparaître Pèlerine et son arme.
4. Une jauge indique au joueur le temps restant.
5. Pèlerine poursuit le Loup, lui retire des demi-cœurs avec ses coups et l’élimine lorsque sa vie est épuisée.
6. À l’expiration, le personnage redevient Rubine.

La confrontation produit un nuage de bagarre cartoon, accompagné d’étoiles et d’un son de coup exagéré. Le Loup éliminé quitte les interactions de la partie.

### Cœurs en acier

**Pèlerine est indestructible face à toutes les attaques.** Ses cœurs sont représentés en acier et ne diminuent pas sous les coups, y compris ceux du Loup Alpha. Cette protection dure tant que le joueur est transformé en Pèlerine. Elle ne prolonge pas la transformation. La vie de Rubine conservée ou restaurée à la fin de cette transformation reste à décider ; aucun soin automatique n’est établi.

### Compétence spéciale : Lance de canne

Pèlerine lance sa canne comme une **lance propulsée par une fusée**, avec un guidage de **tête chercheuse** vers le Loup ciblé. Sa réplique est : **« Sale imposteur, mange-toi ça ! »**

**Si elle touche le Loup, la canne retire un cœur et demi.** Le guidage ne garantit donc pas un impact. **Le délai de réutilisation est fixé pour le moment à 7 secondes.** La portée, le ciblage, les obstacles, l’esquive, le retour ou remplacement de la canne et l’accès à cette compétence avec le marteau restent à définir. Le point de départ du délai et sa conservation entre deux transformations restent à préciser.

La mise en scène doit offrir une animation spectaculaire et lisible : préparation expressive, propulsion, trajectoire guidée et impact cartoon. Ces étapes visuelles sont une direction de production ; leurs détails restent à valider.

**Propositions d’équilibrage :**

- Un court mouvement de préparation rend le coup lisible et esquivable.
- La canne favorise l’agilité et le marteau une portée de frappe plus confortable ; les valeurs restent à tester.
- Pèlerine reste temporaire et invulnérable aux attaques ; l’équilibrage porte sur sa durée, ses déplacements et ses possibilités de frappe.
- Une Pèlerine ne peut pas éliminer un villageois avec son arme.
- Les objets de transformation sont limités pour conserver le danger des Loups.

Les équipements et boosts de partie sont distincts des skins : les pouvoirs viennent des objets obtenus en jeu ou, pour les boosts concernés, achetés dans la future boutique.

## 10. Les tâches et les objets

Les tâches encouragent l’exploration et la prise de risque. Elles peuvent fournir des objets ou des fragments nécessaires à une transformation.

**Exemples proposés :** réparer une lanterne, retrouver une clé, ouvrir un coffre, récupérer des ingrédients ou réparer un mécanisme dans une remise.

Une tâche doit être courte, compréhensible sur téléphone et interrompable. Un joueur en train d’agir doit pouvoir percevoir l’arrivée d’un danger et reprendre le contrôle.

Les objets de transformation peuvent être présentés comme un châle enchanté ou un objet associé à Pèlerine. Leur nom définitif et les conditions d’obtention restent à choisir.

Dans les conditions de victoire convenues, accomplir les tâches n’offre pas une victoire automatique. Elles servent à obtenir des moyens de survie et de chasse.

### Pièces de bronze et future boutique de boosts

**Les pièces de bronze seront utilisées dans La Soirée de Mère-grand.** Elles pourront être récoltées grâce aux **activités pendant la journée**, aux **défis** et à l’**élimination d’un Loup avec Pèlerine**, entre autres récompenses à définir.

Les activités de journée s’ajoutent au débat et au vote déjà décrits. Leur place dans le déroulement du jour, leurs durées et leurs interactions avec le conseil restent à fixer.

Une **boutique de boosts** est prévue pour ce mode. Le boost de capuche et le bonus Loup Alpha pourront y être achetés. Les prix, la monnaie exacte de chaque achat, les quantités, la consommation, les limites d’équipement et l’accès à la boutique avant ou pendant une partie restent à définir. L’usage des pièces de bronze est confirmé, sans imposer encore un tarif ou un catalogue complet.

Les montants gagnés, l’attribution de la récompense lorsqu’un Loup subit plusieurs attaques, le partage éventuel du portefeuille existant et la conservation des boosts entre les parties restent à préciser. Aucun mécanisme de boutique ou de récompense de ce mode n’est encore implémenté.

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

Quatre références visuelles fournies par Logan sont désormais conservées : **Le Domaine de Pèlerine**, **Le Village Endormi**, **Le Vieux Moulin et les Marais** et **La Scierie de la Forêt Noire**. Voir [les références des cartes et leur préparation 3D](soiree-de-mere-grand-cartes-3d.md). Elles guident la direction visuelle ; leur circulation, leurs dimensions et leur capacité réelle à vingt joueurs restent à valider dans le moteur. Le domaine ci-dessous conserve son statut de première carte proposée.

La carte peut réunir quatre zones reliées :

| Zone | Intérêt de jeu | Exemples d’éléments |
|---|---|---|
| Maison de Pèlerine | Tâches et poursuites à courte distance, accès au sous-sol | Entrées opposées, cuisine, armoires, frigos, dessous de tables, dessous de draps, dessous de lits, rideaux et cachettes aménagées au sous-sol |
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
- Vie : trois cœurs pour Rubine et le Loup, avec affichage des demi-cœurs ; cœurs en acier pour Pèlerine. La visibilité de la vie des autres joueurs reste à définir.
- Pouvoirs : durée restante de l’invisibilité et du boost Alpha, disponibilité de la Lance de canne et boosts possédés.
- Pièges : jauge de résistance et retours de dégâts/destruction ; leur affichage doit respecter les règles de détection du piège, encore à définir.
- Frigo : avertissement de froid et perte progressive de vie pour Rubine ; pour le Loup, jauge circulaire de 5 secondes, compteur d’appuis de 0 à 20, instruction Attaque et résultat de la libération. En cas d’échec, afficher les 5 secondes de gel restantes.
- Dans le chat : HELP, événements publics et discussion selon la phase.
- Pour un fantôme : indication claire Spectateur et commandes d’observation.
- Pour le MDJ : commandes de phase et vue privée séparées des contrôles des joueurs.
- Avant le début de la partie : vue d’ensemble de la carte pour choisir son emplacement de départ après le lancement par le créateur du salon.

Les alertes de transition doivent rester visibles lorsqu’un joueur consulte le journal. Les changements importants utilisent un retour visuel et sonore, tout en respectant les réglages de son et de réduction des animations.

## 17. Présentation 3D et sons

Les personnages partagent une direction artistique chibi : grosses têtes, corps compacts, silhouettes faciles à distinguer et mouvements expressifs.

Rubine utilise des couleurs chaleureuses centrées sur le rouge. Pèlerine est immédiatement identifiable par sa silhouette de grand-mère et son arme. Le Loup conserve une silhouette quadrupède, avec un museau, des oreilles et une queue lisibles dans l’obscurité.

Le travail sonore proposé comporte des pas, du vent, des feuillages, des interactions, la torche, les transformations, le HELP, la dévoration stylisée et la bagarre de Pèlerine. Les sons doivent informer le joueur sans révéler automatiquement une identité secrète.

Ajouter les effets de capuche enchantée et d’invisibilité, l’activation et la fin du boost Alpha, les réactions aux pertes de cœurs, les cœurs en acier et la Lance de canne avec sa réplique. Les effets visibles par le joueur ne doivent pas trahir Rubine invisible aux Loups.

La transformation en Pèlerine utilise la phrase « Sauve-moi, Pèlerine ! ». Les pièges demandent des effets de bois et d’épines, de plantes sauvages, de gel et de fuite en criant après le bain chaud, ainsi qu’une destruction lisible lorsque leur résistance est épuisée.

Le frigo demande aussi des réactions au froid pour Rubine, la poussée et l’enfermement du Loup, sa tentative de libération, puis une sortie réussie ou une sortie dans un glaçon en cas d’échec. Les retours d’interface doivent rester lisibles sans révéler une Rubine cachée au Loup.

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
| Cachette | 25 secondes maximum, puis délai de réutilisation |
| Objets de transformation équipés | Un emplacement par villageois |
| Transformations simultanées | À limiter selon le nombre de Loups ; valeur à tester |

Ces valeurs ne sont pas des règles déjà validées. Elles servent à lancer les essais d’équilibrage. Elles ne remplacent pas les valeurs convenues ci-dessous.

### Valeurs convenues le 5 novembre 2026

| Règle | Valeur retenue |
|---|---|
| Vie de Rubine | 3 cœurs |
| Vie du Loup | 3 cœurs |
| Coup ordinaire de Pèlerine sur le Loup | ½ cœur |
| Lance de canne réussie sur le Loup | 1½ cœur |
| Réutilisation de la Lance de canne | 7 secondes pour le moment |
| Attaque simple du Loup sur Rubine | 1 cœur |
| Attaque du Loup Alpha sur Rubine | 2 cœurs |
| Protection de Pèlerine | Cœurs en acier ; invulnérabilité à toute attaque |
| Invisibilité par boost de capuche | 10 secondes |
| Boost Loup Alpha | 20 secondes |
| Durée de la forme Pèlerine | 10 secondes ; 15 secondes selon le compte, critères à définir |
| Trois pièges différents subis par le Loup | Perte de ½ cœur ; remise à zéro du compteur à préciser |
| Piège dont la résistance est épuisée | Disparaît |
| Libération du frigo piégé | Atteindre 20 appuis sur Attaque avant la fin des 5 secondes ; jauge circulaire |
| Échec du Loup à se libérer du frigo piégé | Sort gelé dans un glaçon pendant 5 secondes et perd 1 cœur |
| Rubine cachée dans un frigo | Gel et perte lente de vie ; rythme et dégâts à définir |

Les fréquences d’attaque, les esquives, les délais des pouvoirs et les éventuels soins restent à définir et à tester.

## 19. Règles de fiabilité pour le développement

Le serveur de partie devra valider les captures, les distances d’interaction, les murs, l’occupation des cachettes, les objets, les transformations, les votes et les victoires.

La phase de placement devra également être validée par le serveur : destinations autorisées et praticables, acceptation de plusieurs joueurs au même endroit, téléportation selon les choix confirmés et fin du placement avant les déplacements et les attaques.

Il devra également valider les dégâts en demi-cœurs, l’invulnérabilité de Pèlerine, la durée des boosts, le guidage et les impacts de la canne, les pièges et leur franchissement par l’Alpha. Les attributions de bronze, achats et consommations de boosts devront être vérifiés sans pouvoir être doublés par une répétition de requête. Les chronomètres d’invisibilité et d’Alpha, comme celui de Pèlerine, appartiennent à la partie.

Le serveur devra suivre les déclenchements de pièges subis par chaque Loup, leur résistance et leur destruction, ainsi que le délai de 7 secondes de la Lance de canne. Les critères de compte autorisant 15 secondes en Pèlerine devront être vérifiés côté serveur une fois définis.

Le serveur devra également gérer les dégâts progressifs de froid de Rubine et valider l’épreuve de libération du Loup : fenêtre d’appuis, progression, issue et unique application du cœur perdu en cas d’échec. Mettre l’application en arrière-plan ne doit ni interrompre les dégâts ni prolonger le temps accordé.

Les informations secrètes ne doivent pas être transmises à un joueur non autorisé. Une Rubine cachée ne doit pas réapparaître par un portrait, un marqueur ou une position exposée au Loup. Les fantômes et leur communication doivent être isolés des vivants.

Le chronomètre d’une transformation appartient à la partie, pas au téléphone : mettre l’application en arrière-plan ne doit pas prolonger un pouvoir. Les règles de reconnexion sont à définir ; une courte période de reprise avec un personnage encore présent dans le monde est proposée. Le MDJ peut disposer d’une pause globale.

Les commandes du MDJ et les messages système doivent être authentifiés. Les nouveaux événements de ce jeu ne doivent pas être confondus avec les événements des anciennes parties de cartes.

Le choix du moteur 3D, de son intégration dans Mordeviel et du serveur de déplacement est une prochaine décision technique. Ce document ne suppose pas que le moteur actuel des cartes gère déjà les mouvements 3D.

## 20. Décisions restant à finaliser

1. Minimum de participants et nombre maximal de Loups autorisé.
2. Durée des manches et cachettes ; critères de compte donnant 15 secondes en Pèlerine au lieu de 10.
3. Règles de frappe/esquive, fréquence des attaques, soins éventuels et vie de Rubine à la fin de Pèlerine. L’invulnérabilité de Pèlerine aux attaques est désormais fixée.
4. Conditions précises pour gagner les objets de transformation.
5. Révélation du camp après le vote.
6. Informations visibles par les fantômes autres que l’identité de leur agresseur.
7. Fonctionnement des communications nocturnes.
8. Reconnexion et pause de partie.
9. Moteur 3D et intégration technique.
10. Portée, guidage, obstacles et récupération de la Lance de canne ; disponibilité avec le marteau ; départ et conservation du délai de 7 secondes entre transformations.
11. Pose, obtention, détection, résistance et durée des effets des pièges ; remise à zéro du compteur après trois pièges différents et interaction avec l’Alpha. Sa durée est fixée à 20 secondes.
12. Interactions de l’invisibilité avec les sons, collisions, attaques, objets et changements de phase ; aucun dévoilement automatique par l’Alpha n’est établi.
13. Organisation des activités de journée et barèmes des récompenses de bronze.
14. Catalogue, prix, monnaies d’achat, consommation, stockage et limites des boosts ; articulation avec le portefeuille existant.
15. Vie du joueur Loup lorsqu’il reprend l’apparence de Rubine le jour et conservation des cœurs entre les phases.
16. Froid du frigo : délai initial, rythme des pertes de vie et effets après la sortie de Rubine.
17. Frigo piégé : déclenchement et poussée, relation avec la résistance, cumul avec le compteur de trois pièges différents et interaction avec l’Alpha. L’épreuve est fixée à 20 appuis avant la fin de 5 secondes, puis 5 secondes de gel en cas d’échec.
18. Placement initial : sélection libre ou points prédéfinis, visibilité des autres choix, confirmation, durée et absence de choix ; gestion visuelle et physique d’une arrivée groupée au même endroit. Aucune séparation minimale entre joueurs n’est imposée.

Les noms retenus sont **Pèlerine**, **Rubine** et **le Loup**. Les règles, les modèles et les skins doivent conserver ces appellations.
