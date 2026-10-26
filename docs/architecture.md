# Architecture initiale

## Spécifications de jeu

- [Deck Classique validé](regles-classiques.md)
- [Variantes expérimentales et arbitrages proposés](variantes-test.md)
- [Structure de données proposée](donnees-jeu.md)

- `apps/le_loup` : interface Flutter, Android/iOS, et clients web/Windows générés.
- `packages/local_host` : serveur et client WebSocket Dart natifs, branchés au salon Flutter ; incompatibles web (`dart:io`).
- `backend` : serveur distant FastAPI.
- `docs` : décisions et contrat partagé.

## Principes

Le serveur actif fait autorité : rôles, permissions, phases, échéances et votes.
Chaque client reçoit seulement les informations qui lui sont autorisées.
Les graphismes et sons sont lus sur les clients depuis des ressources locales.
Le vocal distant utilisera un service WebRTC séparé ; aucun flux vocal local.
PostgreSQL sera ajouté avec les comptes et les données persistantes.

## Protocole prévu, version 1

Les deux serveurs devront exposer le même contrat de jeu. L'endpoint `/health`
est disponible. Le serveur LAN implémente `/ws` pour le salon ; FastAPI ne l'implémente pas encore.

Entrée actuelle : `{"version":1,"type":"room.join","nickname":"Alice","code":"123456"}`.
Le serveur répond par `room.joined` (identifiant et jeton privé de session), puis
`room.snapshot` (MDJ, code, inscriptions, joueurs, composition, phase et réglage Voyante).
`player.ready` accepte un booléen `ready`. `error` fournit un champ `message`.
La connexion WebSocket identifie le joueur : aucun identifiant client n'est accepté pour agir sur un autre joueur.
Le MDJ manipule le serveur directement ; aucun événement WebSocket ne permet
de fermer le salon ou d'expulser un joueur. Le code est aléatoire, les pseudos
sont uniques sans distinction de casse, et le salon est limité à 20 joueurs.
Après distribution, `game.role` transmet uniquement le rôle du destinataire.
`room.resume` avec code et jeton reprend une place déconnectée, même si les
inscriptions sont fermées. Un pseudo ou code public seul ne suffit pas.
Le jeton reste en mémoire du client, sans persistance après fermeture de l'application.
Les attributions complètes restent dans `LocalHost.snapshot` pour l'interface MDJ ;
seul `publicSnapshot` est diffusé aux joueurs. La distribution est unique et
verrouille configuration, inscriptions et retraits. Les rôles sont mélangés avec Random.secure.
Les changements de configuration annulent les confirmations des joueurs.
À définir : phase.changed, chat.message, vote.cast, sauvegarde persistante et
identifiants de requête pour les actions de jeu.
Les réponses privées et publiques doivent être distinctes. Une reconnexion devra
restaurer une vue autorisée depuis le serveur, sans redistribuer les rôles.

## Contraintes LAN

Hôte mobile au premier plan, permissions réseau par plateforme, découverte par
QR/adresse, et validation sur téléphones physiques. Les réseaux invités peuvent
isoler les appareils. Le salon distribue les cartes mais ne résout pas encore les tours. L'hébergement web
n'est pas pris en charge. Pas de découverte automatique ni de QR dans ce prototype.

Android : permission INTERNET déclarée, cible actuelle 36 (SDK Flutter installé).
Avant une cible 37+, déclarer et demander ACCESS_LOCAL_NETWORK à l'exécution :
https://docs.flutter.dev/platform-integration/android/local-network-permission
iOS : description de permission réseau local déclarée ; validation physique requise.
Le maintien de l'écran utilise wakelock_plus. Le passage en arrière-plan reste
une interruption potentielle ; aucun service mobile permanent n'est promis.

