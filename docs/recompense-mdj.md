# Récompense du maître du jeu

Le MDJ connecté à un compte vérifié reçoit des Lunes d’or à la fin d’une partie enregistrée par le serveur. Le reçu est distinct d’une victoire ou d’une défaite et porte le type `participant_role: mdj`.

Le montant suit le nombre de nuits et le barème progressif de l’édition, indépendamment du camp gagnant, y compris en cas de partie nulle :

| Nuits | Classique | Intense | Horreur |
|---|---:|---:|---:|
| 0 | 0 | 0 | 0 |
| 1 | 20 | 50 | 55 |
| 2 | 24 | 55 | 64 |
| 3 | 28 | 60 | 73 |
| 4 | 32 | 65 | 82 |
| 5 | 36 | 70 | 91 |
| 6 et plus | 40 | 75 | 100 |

Les parties avec bots sont incluses, même si le MDJ est le seul humain. Les défis entre joueurs humains conservent leurs propres conditions. Le compte du MDJ doit toujours être celui associé au salon, avec une association valide ; les comptes bannis ou non vérifiés ne sont pas crédités.

Le crédit est enregistré une seule fois à la fin de partie, dans la même transaction que les autres résultats. Le coffre et sa vidéo présentent ce crédit sans ajouter une seconde fois le montant. Le MDJ retrouve aussi le reçu et le coffre non ouvert dans sa bourse.

La modification s’applique aux prochaines parties terminées après déploiement. Elle ne recalcule pas les anciens résultats. Le mode purement local sans compte et sans serveur n’est pas crédité.

La colonne ajoutée aux reçus est migrée au démarrage du serveur ; les anciens reçus restent des récompenses de joueurs. Un nouveau build de l’application affiche les libellés MDJ dans le coffre et dans la bourse.
