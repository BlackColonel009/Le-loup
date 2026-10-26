# Variantes — propositions à tester

Statut : expérimental, non implémenté. Aucun de ces pouvoirs ne fait partie
du standard. Les ajustements ci-dessous sont des propositions à confirmer.

## Métamorphe

Proposition reçue : échange une fois deux rôles en secret, avec notification
des deux cibles ; les ressources consommées restent attachées à la carte.

Base de test recommandée :

- Camp Village pour ce premier prototype : ne pas créer un camp neutre sans
  objectif de victoire. « Variable selon la cible » reste ambigu lorsqu'il y a deux cibles.
- Agit une seule fois, la première nuit, avant la Voyante.
- Sélectionne deux autres joueurs vivants distincts ; ne peut pas se cibler.
- Échange le rôle, le camp associé et les ressources de l'instance de rôle.
- Le statut vivant, le pseudo, la maison et les conversations passées restent
  attachés au joueur. Ne jamais transférer d'historique de chat privé.
- Les cibles sont informées immédiatement de leur nouveau rôle.
- Après échange, recalculer l'accès de la meute avant l'ouverture de son canal.
- Pour le premier test, incompatible avec Infection afin d'éviter les conflits
  entre rôle déplacé et changement de camp différé.

À confirmer : camp Village, exclusion de soi, cibles déjà informées du rôle
initial, comportement en cas d'absence de choix. Avec une activation limitée
au début, les potions n'ont normalement pas encore été consommées ; la règle
de conservation servira aux futures variantes d'activation tardive.

## Bouclier

Proposition reçue : effet de protection qui absorbe une attaque de loups
ou de potion de mort et expire en fin de nuit.

Différence avec la piste précédente : celle-ci annonçait une protection de la
nuit suivante. Le délai n'est donc pas encore validé.

Base de test recommandée :

- Effet, pas rôle autonome. Le rôle ou objet qui l'accorde, son nombre
  d'utilisations et l'auto-protection restent à définir.
- Posé pendant la nuit N ; actif pendant la nuit N+1 uniquement.
- Absorbe une seule attaque mortelle, puis disparaît.
- Expire à l'aube N+1 s'il n'est pas consommé ; aucun cumul de boucliers.
- Priorité proposée : potion de vie annule d'abord l'attaque des loups,
  puis bouclier contre l'attaque restante des loups, puis contre la potion de mort.
- Deux attaques non annulées peuvent donc tuer une cible portant un seul bouclier.
- Ne bloque ni le vote, ni le tir du Chasseur, ni une mort liée aux amoureux.
- Protection et consommation ne sont connues que du MDJ et du détenteur du pouvoir,
  sauf règle explicitement annoncée.

À tester : ordre des attaques, lisibilité du délai et information de la Sorcière.
Infection non couverte pour le premier test : ce n'est pas une attaque mortelle.

## Infection

Proposition reçue : remplace l'attaque mortelle ; conversion notifiée au
début de la nuit suivante. La cible ignore la contamination pendant le jour.

Base de test recommandée :

- Une charge d'infection pour la meute entière sur toute la partie.
- La meute confirme unanimement le mode « infecter » et la même cible vivante
  non-loup. Sans accord, aucune action de meute.
- La charge est consommée à la résolution de l'infection.
- Nuit N : pas d'attaque mortelle de meute ; contamination en attente privée au MDJ.
- Jour N+1 : cible encore Village, avec ses pouvoirs et sa condition de victoire habituels.
- Début de nuit N+1, avant tout appel de rôle : si la cible vit encore et que
  la partie continue, elle devient un Loup-Garou simple et reçoit l'information.
- Son ancien pouvoir est retiré ; elle rejoint alors seulement le canal de meute.
- Si elle meurt avant la conversion, annuler la contamination, sans rendre la charge.
- Les conditions de victoire ignorent une conversion encore en attente : si
  tous les loups meurent avant son activation, le Village gagne et elle est annulée.
- La potion de vie et le Bouclier n'annulent pas cette contamination dans cette
  base de test ; cette interaction doit être annoncée dans le Codex.

La notification différée est cohérente seulement si le changement effectif de
camp est lui aussi différé. Aucun joueur ne doit gagner ou perdre pour un camp
qu'il ne sait pas avoir rejoint.

À confirmer : perte du pouvoir initial, charge unique, immunités et conditions
exactes de consommation. Tester d'abord indépendamment du Métamorphe.
