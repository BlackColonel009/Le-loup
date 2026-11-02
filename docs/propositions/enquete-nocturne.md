# Mise à jour ultérieure — Enquête nocturne

Enregistrée le 2 novembre 2026 à la demande de Logan. **Projet reporté : aucune mise en œuvre dans la livraison immersion/vocal actuelle.**

## Intention

Créer un mode de jeu d'exploration et d'enquête : déplacements secrets sur une carte, rencontres et observations partielles alimentant les débats du lendemain. Le choix de ce mode sera distinct du thème visuel et des capacités propres à chaque carte.

La proposition initiale de Gemini est archivée dans [le texte source](enquete-nocturne-gemini.txt). Le [visuel de référence](enquete-nocturne-reference.jpg) est une maquette de présentation ; il ne constitue pas un terrain directement exploitable par l'application.

## Pistes à reprendre avec Logan

- Village central avec les maisons des participants, place du conseil, forêt, moulin, grotte et marais. Un relais ou une cabane pourrait remplacer le nom peu clair « Tenture du Chasseur ».
- Première version envisagée : déplacements par tours, avec choix secrets et résolution simultanée sous le contrôle du MDJ, puis appels habituels des rôles.
- Brouillard de guerre et observations calculés par le moteur Dart. Le téléphone reçoit uniquement les informations auxquelles son joueur a droit.
- Indices incomplets, silhouettes et traces ; identification d'un personnage uniquement lorsqu'une règle explicite l'autorise.
- Plusieurs rôles peuvent fréquenter les mêmes lieux. Un passage en forêt ne doit pas identifier automatiquement un loup.
- Portrait et paysage permettent d'explorer le même terrain et offrent les mêmes possibilités d'observation.
- Réutiliser les salons, cartes, appels du MDJ, votes, chats et conditions de victoire lorsque les nouvelles règles le permettent.

## Règles à définir avant développement

1. Destinations, chemins, durée et budget de déplacement ; gestion des immobilités et déconnexions.
2. Ordre entre déplacements, observations, attaques, protections, potions et réactions de mort.
3. Portée des actions et visibilité des rencontres. L'observation ne doit pas devenir un pouvoir supplémentaire gratuit de la Voyante.
4. Effets éventuels des lieux, annoncés dans le Codex et limités dans le temps.
5. Informations publiques du matin et informations privées conservées par les témoins.
6. Adaptation des bots et équilibrage selon le nombre de joueurs et les compositions mixtes.
7. XP et classement évoqués par Gemini : à discuter séparément, sans les considérer comme déjà définis.

## Limites retenues pour la conception

Pas de marqueur public révélant le camp d'un joueur vivant. Ne pas transmettre toutes les positions secrètes aux appareils en comptant sur un simple masquage graphique. Éviter les destinations obligatoires qui révèlent un rôle, ainsi que les sanctions ou morts de zone sans règles compréhensibles.

L'implémentation actuelle utilise des maisons fixes et des fantômes décoratifs. Les déplacements jouables, les chemins et les rencontres demanderont une extension du moteur, du protocole et de l'interface. Ce document réserve cette évolution pour une prochaine discussion avec Logan.
