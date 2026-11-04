# Lunes d’or et coffres de défis — 4 novembre 2026

## Gains de partie

Les pièces s’appellent **Lunes d’or**. Leur solde est lié au compte, conservé sur le serveur et visible dans la barre du haut. Toucher ce solde ouvre la bourse et les 50 derniers gains. Les achats avec ces pièces seront développés plus tard.

Les parties en ligne donnent des pièces aux comptes participants, **bots compris dans le salon**. Les bots et le MDJ observateur ne possèdent pas de bourse récompensée. Les joueurs éliminés conservent leur gain si leur camp gagne. Le moteur fournit les vainqueurs, le nombre de nuits et le thème ; aucun montant proposé par le téléphone n’est accepté.

| Nuits de partie | Défaite | Victoire classique | Victoire intense | Victoire horreur |
|---:|---:|---:|---:|---:|
| 1 | 1 | 20 | 50 | 55 |
| 2 | 2 | 24 | 55 | 64 |
| 3 | 3 | 28 | 60 | 73 |
| 4 | 4 | 32 | 65 | 82 |
| 5 | 5 | 36 | 70 | 91 |
| 6 | 5 | 40 | 75 | 100 |

Les victoires atteignent leur plafond à la sixième nuit ; les suivantes gardent ce maximum. Une victoire sans nuit complète reçoit le minimum ; une défaite reçoit au moins une pièce. En partie mixte, le palier dépend du décor sélectionné, pas de la rareté d’une carte individuelle.

## Enregistrement et présentation

Le solde est crédité une seule fois dans la même transaction que le résultat de partie. Une contrainte `(match_id, user_id)` interdit le double gain. Le bouton Continuer affiche un coffre qui tremble. Il ouvre ensuite le coffre puis la vidéo de Logan : 10 secondes, 45 marqueurs d’impacts sonores et compteur par paliers jusqu’au gain exact. Une pièce visible représente une fraction du total, pas nécessairement une seule Lune d’or.

Passer la vidéo révèle immédiatement « Vous avez gagné », l’emblème et le montant exact. Un échec de lecture utilise une animation locale de secours. La vidéo se met en pause en arrière-plan et respecte le volume des effets. Les mouvements réduits ouvrent directement le résultat. Un coffre non consulté reste accessible dans la bourse ; l’ouvrir ne crédite jamais les pièces une seconde fois.

La vidéo a été préparée avec `tools/content/prepare_coin_video.py` depuis le fichier fourni par Logan. Version intégrée : 540 × 960, H.264/AAC, environ 1,85 Mio. Les marqueurs correspondent aux transitoires sonores détectés ; la synchronisation visuelle et sonore finale reste à apprécier sur téléphone.

## Classement des défis

La difficulté est définie dans `shared/challenges/catalog.json` : facile = coffre classique, moyenne = coffre épique, élevée = coffre premium. Le type de cadeau ne détermine plus le coffre pour les défis classés. Les anciennes réponses sans métadonnées conservent leur affichage compatible. Le carnet propose des filtres par coffre.

| Défi | Difficulté | Coffre |
|---|---|---|
| Bienvenue à Mordeviel | Facile | Classique |
| Première nuit | Facile | Classique |
| Première victoire | Facile | Classique |
| Habitué du village | Moyenne | Épique |
| Vétéran de Mordeviel | Élevée | Premium |
| Premiers crocs | Facile | Classique |
| Prédateur nocturne | Élevée | Premium |
| Champion du village | Élevée | Premium |
| Regard perçant | Moyenne | Épique |
| Une seconde chance | Moyenne | Épique |
| Veilleur du village | Moyenne | Épique |
| Dernière balle | Moyenne | Épique |
| Liés par le destin | Moyenne | Épique |
| La meute s’agrandit | Élevée | Premium |
| Solitaire de la lune | Élevée | Premium |
| Mélodie fatale | Élevée | Premium |
| Visages du village | Moyenne | Épique |
| Mille vies | Élevée | Premium |
| Simple citoyen | Moyenne | Épique |
| Dans chaque camp | Moyenne | Épique |
| Les trois univers | Moyenne | Épique |
| Le bon verdict | Moyenne | Épique |
| Vision nocturne | Moyenne | Épique |
| Remède précieux | Élevée | Premium |
| Sous bonne garde | Moyenne | Épique |
| Dernier rempart | Élevée | Premium |
| Mémoire ancienne | Élevée | Premium |
| Hurlement victorieux | Moyenne | Épique |
| Longue chasse | Moyenne | Épique |
| Sang nouveau | Élevée | Premium |
| Faim insatiable | Élevée | Premium |
| Trahison blanche | Élevée | Premium |
| Amour impossible | Élevée | Premium |
| Victoire céleste | Élevée | Premium |
| Tout le village danse | Élevée | Premium |
| Seul sous la lune | Élevée | Premium |
| Collectionneur de destins | Élevée | Premium |
| Rendez-vous au village | Moyenne | Épique |
| Fidèle aux nuits | Élevée | Premium |
| Soirée entre amis | Moyenne | Épique |
| Nuit de fête | Moyenne | Épique |
| Mémoire des saisons | Élevée | Premium |

## Déploiement

Publier le backend, le fichier partagé du catalogue et l’application. Au démarrage, les tables `coin_wallets` et `coin_match_rewards` sont créées automatiquement. Aucun nouveau paquet Python n’est requis sur le serveur. Les anciennes parties ne sont pas créditées rétroactivement. Reconstruire l’application pour inclure la vidéo et son compteur. Aucun APK n’est construit par les vérifications.

API : `GET /coins/me`, `GET /coins/matches/{id}`, `POST /coins/matches/{id}/claim`. La dernière route confirme l’ouverture du coffre ; elle ne modifie pas le solde. Les données de la bourse et des gains sont supprimées avec le compte.
