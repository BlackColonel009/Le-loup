# Structure de données proposée

Spécification de préparation, sans modification du protocole de salon existant.
Le serveur Dart local et FastAPI devront respecter les mêmes contrats et scénarios.

| Entité | Informations |
| --- | --- |
| Session | identifiant, version des règles, phase, échéance, pause, MDJ |
| Configuration | ambiance, règles standard/variantes, composition, options annoncées |
| Joueur | identifiant, pseudo, maison, connexion, vivant, prêt |
| Définition de rôle | identifiant stable, description, camp initial, pouvoirs |
| Instance de rôle | identifiant unique, définition, détenteur, ressources restantes |
| Action | auteur, pouvoir, cibles, phase, statut, identifiant de requête |
| Effet | type, cible, source, début, expiration, charges, priorité |
| Résolution | actions validées, décès, réactions en attente, résultat final |

L'instance de rôle permet de déplacer une carte et ses ressources sans déplacer
le joueur. Le camp effectif est calculé depuis le rôle et les effets actifs.
Une infection en attente n'affecte pas encore ce camp.

Prévoir des vues séparées :

- Publique : Codex, options, phase et événements publics autorisés.
- Joueur : sa carte, ses ressources, ses résultats et canaux autorisés.
- MDJ : état complet et commandes d'arbitrage.

Ne jamais envoyer l'état complet au client pour ensuite masquer ses secrets.
Les événements doivent être validés par le serveur, dédupliqués et rattachés
à une phase. Reconnexion, sauvegardes et reprise nécessitent des jetons privés,
distincts du code public du salon. Le journal complet reste réservé au serveur/MDJ.

Les décès sont résolus par une file de réactions avant la vérification de victoire.
Les priorités des variantes doivent être fixées avant leur implémentation.
