# Historique final et sélections

## Bilan des manches

Le moteur conserve un journal chronologique propre au salon : appels du MDJ,
actions acceptées avec leur auteur et leurs cibles, visions, potions, échanges
de cartes, amoureux, protections, charmes, espionnage, infections, tirs,
éliminations et sentences. Les effets automatiques (résistance de l’Ancien,
protection réussie, conversion, malédiction et transformation de l’Ange) sont
consignés lorsqu’ils se produisent.

Chaque modification de vote apparaît ; le résultat du scrutin présente les
bulletins définitifs, votes blancs, abstentions, égalités et éventuelles grâces.
Une tentative refusée n’entre pas dans le journal. Les contenus des chats ne
sont pas archivés dans ce bilan.

Le champ réseau `game.history` n’est publié **qu’en phase `ended`**. Il révèle
alors les actions secrètes à tous les participants. Avant cette phase, le champ
est absent, y compris pour les spectateurs. Les copies envoyées sont détachées
des données internes du moteur. L’écran refuse lui aussi un bilan avant la fin.

Accès : « Revivre toutes les manches » sur la victoire, puis bouton d’historique
dans les actions de la partie terminée. Les jours et nuits structurent la liste.
Le journal reste en mémoire avec le salon ; il n’est pas un historique permanent
du compte et disparaît avec le salon. Les parties déjà terminées sur une ancienne
version du moteur ne peuvent pas reconstruire les actions disparues.

## Sélections

Les choix affichent désormais l’auteur, son rôle et sa cible sous la forme
« joueur → cible ». Une sélection locale porte la mention « Sélection à
confirmer ». Après réception par le moteur, « Choix confirmé » reste visible,
même si le pouvoir n’est plus cliquable. Vie et Mort restent distinguées pour
la Sorcière ; les actions multi-cibles affichent tous les noms choisis.

Le serveur réserve `confirmed_selection` au joueur concerné et
`confirmed_selections` au MDJ, pour la révision courante uniquement. La meute
conserve ses choix partagés entre loups et voit qui n’a pas encore confirmé.
Aucune sélection nocturne supplémentaire n’est rendue publique en cours de jeu.

## Déploiement

Mettre à jour l’application **et** le moteur Dart sur le serveur :

```bash
cd /var/www/Mordeviel
git pull
sudo systemctl restart mordeviel
```

Pas de nouvelle dépendance Python/Dart ni migration de base. Les nouveaux salons
en ligne utilisent le moteur mis à jour. En local, le moteur est fourni avec
l’application du MDJ. Aucun APK n’est compilé par ces modifications.
