# Refonte des cartes et des pouvoirs par édition

Demande de Logan du 2 novembre 2026 : conserver les pouvoirs du [tableau partagé](propositions/tableau-roles-editions.md) et poursuivre directement leur intégration. Le tableau est archivé intégralement comme référence ; il contient 18 rôles secrets et le titre public de Maire.

## Règles communes

- Le pouvoir dépend de l'édition de chaque carte distribuée, indépendamment de l'environnement choisi. Les parties mixtes doivent fonctionner en local et en ligne avec le même moteur Dart.
- Une carte conserve son identité et ses charges lorsqu'elle est échangée. Les éditions et pouvoirs ne sont pas révélés publiquement par les dos des cartes, les maisons ou les effets d'interface.
- Le MDJ garde le choix des appels disponibles. Chaque capacité décrit ses cibles, son coût, son moment de résolution, ses informations privées et sa durée.
- Les noms, résumés, précisions au dos et le Codex doivent correspondre au comportement du moteur. Les bots doivent utiliser les actions disponibles sans connaître les rôles secrets des autres joueurs.
- Les achats et restrictions de collection existants restent applicables ; l'intégration des pouvoirs ne constitue pas un branchement des paiements.

## Lots de réalisation

1. Terminer les ajustements en cours : maisons Intense recalées, contour lumineux discret, manipulation tactile des cartes avec inclinaison, retournement et inertie.
2. Préserver les huit variantes existantes : Voyante, Métamorphe, Salvateur, Loup-Garou. Vérifier leur conformité au tableau et leurs interactions avec les ajouts.
3. Intégrer Villageois, Sorcière et Chasseur : observation des actions, poisons différés et conditionnels, protection transmise, second tir plafonné.
4. Intégrer Petite Fille, Cupidon, Ancien, Bouc émissaire et Sœurs : espionnage, accords, canaux privés temporaires, présages et décisions publiques.
5. Intégrer Alpha, Loup Blanc, Père des Loups, Idiot, Joueur de Flûte et Ange : attaques, conversions, scrutins et conditions de victoire.
6. Intégrer le titre de Maire, son édition, le second scrutin et le testament ; mettre à jour les cartes, le Codex, les contrôles du MDJ, les joueurs virtuels et l'historique.
7. Vérifier les scénarios mixtes, les morts en chaîne, les échanges et les informations privées. Les tests techniques ne remplacent pas les parties d'équilibrage avec Logan.

## État de réalisation

Les sept lots sont intégrés dans le projet local : 38 fiches Intense/Horreur, actions du moteur, contrôles du MDJ et des joueurs, bots, Codex et historique. Les illustrations existantes sont conservées ; les nouveaux noms et résumés sont composés par l’interface sur le recto, avec les règles détaillées au verso. Aucun APK n’est compilé par l’agent.

## Précisions de résolution

- **Observation** : les actions acceptées sont comptées, une chasse commune compte une fois ; les observations elles-mêmes sont exclues. Le Veilleur marque sa propre maison, uniquement pendant la journée suivante.
- **Sorcière** : le poison différé agit au réveil de la nuit suivante, avec les protections nocturnes applicables. La malédiction agit au crépuscule suivant ; seule l’exécution d’un loup pendant la journée la lève. Les réactions en chaîne sont résolues avant de reprendre la nuit. Le poison est consommé dès confirmation, sans empêcher ensuite de confirmer la potion de vie.
- **Chasseur** : le Franc-tireur choisit entre tir et bouclier contre une seule attaque de la meute. Le Chasseur de monstres dispose de deux tirs maximum ; aucun tir supplémentaire si son pouvoir est désactivé entre-temps.
- **Ancien** : la résistance transmise n’est pas dupliquée. Un présage déjà protégé par une autre capacité ne consomme pas sa résistance ; la déclaration consomme néanmoins sa charge unique.
- **Infections** : la conversion « immédiate » est résolue à l’aube, après les sauvetages. L’infection dormante devient effective au début de N+2 ou peut être activée pendant l’appel de N+1. La cible ignore sa dormance ; sa mort la rend sans effet. Les actions déjà jouées ne sont pas répétées.
- **Ange** : seuls les scrutins de condamnation achevés comptent pour son épreuve, pas l’élection du Maire ni le second tour d’une égalité. L’Ange vigilant devient Éclaireur Intense ; l’Ange du sursis devient Villageois classique après son second échec. Aucune protection nocturne, y compris la potion de vie, ne peut sauver l’Ange du sursis pendant son épreuve.
- **Votes** : terreur, contagion et pacte suspendent les bulletins de condamnation concernés, sans couper la parole. Une révélation du camp demandée par le Bouc maudit ne supprime pas une autre restriction. Le camp publié est celui du moment de la réponse.
- **Seconds scrutins** : un seul second scrutin par procédure. La stratégie du Maire est prioritaire, sans consommer la charge du Médiateur. Le Médiateur ne vote pas au second tour ; le Maire stratège a un vote simple pendant les deux tours. Aucun troisième scrutin.
- **Maire** : le titre et son édition sont indépendants de la carte secrète. Le testament n’est public qu’à la mort, après les réactions. Un successeur déjà mort rouvre l’élection ; sans testament, la succession habituelle s’applique.
- **Amoureux et Sœurs** : échanges écrits privés de 60 secondes actives maximum, interrompus par la pause du MDJ et effacés à la fermeture de l’appel. Ni les autres joueurs ni le MDJ ne reçoivent leurs messages ; ils ne sont pas copiés dans l’historique. Un accord mutuel est indispensable aux pouvoirs de pacte et de serment. Le pouvoir est commun à une paire de Sœurs : deux cartes de même édition ne le doublent pas.
- **Échanges de cartes** : identité, édition, charges et mémoire propres à la carte la suivent. Infections, amour, charmes et effets déjà déposés sur une personne restent attachés à cette personne.

Les nouveaux appels Éclaireurs/Veilleurs, Ancien et Amoureux ont leurs instructions écrites. Les enregistrements audio existants sont conservés ; aucune nouvelle réplique audio n’est prétendue disponible pour ces appels.

## Vérification et livraison

Les vérifications couvrent les variantes, mélanges, pouvoirs consommés, choix privés, effets différés, morts en chaîne, scrutins, bots, canaux temporaires et droits du MDJ. Les 38 rectos sont contrôlés avec du texte agrandi. La carte Intense et les gestes tactiles possèdent aussi leurs tests dédiés. Des tests FastAPI utilisent le véritable moteur Dart et des connexions locales, sans contacter Contabo.

Les tests techniques ne mesurent ni l’équilibre statistique des camps ni les performances sur les téléphones de Logan. Les parties d’équilibrage restent nécessaires.

**Mettre à jour ensemble le serveur et les applications** pour utiliser les nouvelles règles. Le moteur Dart reste partagé entre local et distant. La fiche du premier lot est conservée comme historique : [premières variantes](variantes-premiers-quatre-roles.md).

Les ajouts décidés pendant cette refonte sont documentés dans [Grimoire, portraits et communauté](avatars-grimoire-communaute.md).
