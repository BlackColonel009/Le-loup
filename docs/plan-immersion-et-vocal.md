# Mordeviel — Plan de mise à jour : immersion et vocal

Date : 1er novembre 2026. Préparé pour Roland DJAGBA Alias Logan.

Statut au 2 novembre : les sept lots sont intégrés localement. Contrôles automatisés réalisés ; validation téléphones et déploiement média encore à effectuer. Voir [le bilan complet](immersion-livraison-complete.md) et [le guide vocal Contabo](deploiement-vocal.md).
Source : [propositions de Graphique.md](../Graphique.md), confrontées au code existant.

## Objectif et découpage

Rendre la carte agréable à parcourir et les interactions plus vivantes, puis intégrer un micro à maintenir pour parler en ligne. Les nouveaux pouvoirs Intense/Horreur feront l'objet d'une autre mise à jour.

Deux livraisons permettent de tester les améliorations graphiques sans attendre l'infrastructure vocale :

1. **Livraison A : stabilité et immersion** — lots 1 à 5.
2. **Livraison B : expression et communication** — lots 6 et 7. Les emotes peuvent être livrées avant le vocal.

Chaque lot suit le même parcours : réalisation ciblée, vérifications utiles, bilan des changements, puis essai de Logan sur téléphone. À sa demande de poursuivre toutes les étapes, les intégrations ont été enchaînées avant la validation finale sur appareils. Une anomalie bloquante découverte lors d'un lot est traitée avant d'empiler de nouveaux effets.

## Architecture à conserver

| Couche existante | Responsabilité pendant cette mise à jour |
|---|---|
| Flutter, `apps/mordeviel` | Gestes, caméra du village, animations, réglages, lecture des sons et interface du micro. |
| Moteur Dart, `packages/local_host` | Phases, rôles, vivants/éliminés, autorisations des actions et canaux autorisés. Les animations ne déterminent jamais une élimination ou un changement de phase. |
| FastAPI, `backend/src/mordeviel_api` | Accès aux salons en ligne, authentification, packs et futurs accès temporaires au vocal. |
| Packs, `tools/content/build_packs.py` et `shared/content/catalog.json` | Distribution des nouveaux médias, versions, tailles et sommes de contrôle. Les téléchargements installés sont conservés. |
| Futur transport vocal | Transmission audio séparée des messages WebSocket de jeu. Sa technologie et son déploiement seront fixés au lot 7. |

Les lots graphiques ne nécessitent pas de réécrire le moteur ni le backend. Un événement partagé n'est ajouté au protocole que si les autres joueurs doivent réellement le recevoir.

## Lot 1 — Carte stable, caméra et gestes

Priorité : première réalisation.

Avancement du 1er novembre : corrections intégrées et vérifications automatisées réussies. Essai et mesure de fluidité sur téléphone encore à effectuer. Détails : [bilan du lot 1](immersion-lot-1.md).

**Constat actuel :** `VillageMap` possède déjà un `InteractiveViewer`, un contrôleur de transformation, le pincement, les boutons de zoom et une vue d'ensemble. Le plantage mentionné dans l'audit reste à reproduire ; sa cause n'est pas établie.

- [ ] Reproduire le blocage par toucher, déplacement et pincement ; identifier s'il s'agit d'une exception, d'une saccade ou d'un conflit de gestes.
- [x] Vérifier les interactions entre la carte, les maisons et le défilement de la page : toucher sélectionne, glisser déplace, pincer zoome, sans sélectionner involontairement une maison.
- [x] Stabiliser le cadrage initial, les limites de déplacement et le zoom minimal pour Classique, Intense et Horreur.
- [x] Adapter le cadre disponible en paysage ; préserver le rapport du décor et rendre tous les recoins accessibles sans étirer l'image.
- [x] Conserver autant que possible la zone observée lors d'une rotation ou d'un rafraîchissement réseau ; réserver la remise à zéro au bouton « Vue d'ensemble » et aux changements de terrain qui la nécessitent.
- [x] Garder maisons, noms, fantômes et protections attachés au même point du terrain pendant les transformations.
- [ ] Mesurer sur téléphone l'effet de l'isolation des peintures du terrain et de l'ambiance Horreur, puis ajuster si nécessaire.

**Fichiers principaux :** `village/village_map.dart`, `house_sprite_geometry.dart`, `village_navigation.dart` et son intégration dans `lobby_native.dart`.

**Validation :** les trois thèmes, portrait/paysage, petite partie et vingt maisons ; pincement, déplacement aux quatre bords, sélection après zoom, rotation et actualisation d'un salon. Étendre les tests de placement/gestes existants. Mesurer la fluidité sur téléphone physique ; les tests de widgets ne prouvent pas la performance réelle.

## Lot 2 — Manipulation des cartes et retours tactiles

- [x] Ajouter un retour tactile bref au retournement et à la sélection d'une maison, avec un réglage indépendant du volume sonore.
- [x] Prévoir un retour d'élimination discret ; ne pas répéter les vibrations lors d'une reconnexion ou d'un simple rafraîchissement.
- [x] Introduire des mouvements amortis pour l'ouverture, le retour à plat et la fermeture ; le ressort ne doit pas rendre le texte difficile à lire.
- [x] Ajouter une inclinaison légère suivant le doigt, sans conflit avec le glissement vers le bas qui cache déjà la carte.
- [x] Ajouter le coup d'œil : maintenir une carte couverte pour la dévoiler partiellement, puis relâcher pour la masquer. Annuler immédiatement à la perte du toucher, au changement d'application ou à la fermeture.
- [x] Conserver les boutons « Découvrir », « Retourner » et « Cacher » pour l'accessibilité et les usages sans gestes précis.

**Confidentialité :** ces interactions sont locales. Aucun son ou motif de vibration particulier à un rôle secret ne doit le révéler aux personnes présentes dans la pièce.

**Fichiers principaux :** `cards/card_gallery.dart`, préférences d'interaction à ajouter dans `services/`, présentation des réglages existante.

**Validation :** relâchement et annulation du toucher, passage en arrière-plan, consultation des règles au dos, fermeture rapide et animations réduites. Le gyroscope est reporté après validation de l'inclinaison au doigt.

## Lot 3 — Matières, lumières et bruitages

- [x] Ajouter un reflet mobile sobre aux cartes Intense et un traitement inquiétant distinct aux cartes Horreur ; le texte reste lisible.
- [x] Lier le traitement visuel à l'apparence de la carte, y compris en partie Mixte. Ne pas définir la rareté d'une collection à partir de son rôle de jeu.
- [x] Ajouter de courts sons de manipulation de carte, sans saturation ni lecture répétée lors des reconstructions d'interface.
- [x] Envisager des signatures de rôle uniquement pour une écoute privée. En présence de joueurs réunis, conserver un son générique pour la découverte secrète.
- [x] Préserver les effets par cause de mort : griffures, poison, impacts du Chasseur, découpe et perte de la fonction de Maire.
- [x] Réserver une éventuelle dissolution à une finition compatible avec ces effets ; ne pas remplacer systématiquement les animations existantes.

**Fichiers principaux :** `cards/card_gallery.dart`, `village/ceremonies.dart`, composants de dégâts existants et `audio/classic_audio.dart`.

**Validation :** lisibilité recto/dos, trois apparences et partie Mixte ; sons désactivés, réglages de volume et réduction des animations. Un effet manquant ne doit pas bloquer la consultation d'une carte.

## Lot 4 — Village vivant et vol du hibou

- [x] Améliorer les transitions lumineuses existantes et ajouter des fenêtres/cheminées animées avec un nombre limité de particules.
- [x] Conserver la neige Intense, la météo Classique et l'ambiance Horreur ; les effets décoratifs ne donnent aucune indication sur un pouvoir secret.
- [x] Ancrer le hibou perché à une position du décor ; convertir sa position vers l'écran pour son approche, même lorsque la carte est déplacée ou zoomée.
- [x] Remplacer son trajet droit par une courbe avec virages et inclinaison du corps.
- [x] Ajuster la profondeur : déplacement lointain lent, puis rapprochement nettement accéléré. Le grossissement actuel est déjà cubique ; il ne s'agit pas de corriger un zoom entièrement linéaire.
- [x] Animer les ailes avec des transformations de l’illustration existante. Aucune nouvelle séquence bitmap ni modèle 3D articulé n’a été produit ; le réalisme reste à apprécier sur téléphone.
- [x] Synchroniser hululement et passage au premier plan ; ajouter au besoin un flou et un mouvement de caméra très brefs, désactivables.
- [x] Faire revenir le hibou sur son perchoir et préserver les passages intermittents de chauves-souris.

**Fichiers principaux :** `village/horror_ambience.dart`, `weather_overlay.dart`, `village_map.dart`, médias du pack village/ambiance Horreur.

**Validation :** carte zoomée/déplacée, rotation, pause, arrière-plan, frayeurs désactivées et animations réduites. Aucun animal ni effet météo ne doit intercepter les gestes. En local, les sons partagés restent chez le MDJ.

## Lot 5 — Réglages, packs et validation de la livraison A

- [x] Regrouper clairement les réglages : vibrations, intensité visuelle et frayeurs, en réutilisant les préférences existantes lorsque possible.
- [x] Respecter la réduction des animations du système ; prévoir une version sobre pour les appareils moins puissants.
- [x] Réutiliser les packs Horreur existants pour leurs nouveaux médias. Garder les effets procéduraux dans le code et éviter les grosses vidéos embarquées.
- [x] Préserver les versions et fichiers des packs existants. Cette livraison ne modifie pas leurs médias ; aucune nouvelle publication de pack n’est nécessaire.
- [x] Préciser les erreurs de ressources manquantes et conduire vers « Mes téléchargements », comme dans le parcours actuel.
- [ ] Vérifier sur les téléphones de Logan le fonctionnement hors connexion et la conservation des packs après mise à jour de l’application. Les mécanismes et tests existants sont conservés.
- [x] Contrôler les parties locales/en ligne, les trois thèmes et les compositions mixtes, sans modification des règles existantes.

**Fichiers principaux :** `audio/audio_settings.dart`, `content/pack_store_native.dart`, `content/require_packs.dart`, `content/prepare_room_content.dart`, `tools/content/build_packs.py`.

**Sortie attendue :** analyse statique et tests ciblés, captures de comparaison, essai sur téléphone et bilan honnête des limites observées. Logan effectue le build APK et la validation sur ses appareils.

## Lot 6 — Réactions expressives et grimoire

- [x] Réutiliser les stickers existants pour proposer des réactions temporaires au-dessus des maisons, sans exposer d'informations privées.
- [x] Définir côté moteur les destinataires autorisés : réaction publique au conseil, réaction de meute uniquement aux membres autorisés pendant leur appel, aucune réaction d'un éliminé aux vivants.
- [x] Limiter la fréquence et la durée des réactions ; une seule réaction visible par maison à la fois.
- [x] N'afficher une activité « écrit » ou « parle » qu'aux personnes ayant accès au canal concerné. Ne pas afficher publiquement « réfléchit à son pouvoir ».
- [x] Donner une présentation de grimoire à l'historique final existant, avec séparation des manches et navigation lisible.
- [x] En cours de partie, n'utiliser que les événements déjà publics. Conserver le détail des actions secrètes pour la fin et les vues autorisées du MDJ.

**Fichiers principaux :** `stickers/chat_stickers.dart`, `village/village_chat.dart`, `village/village_map.dart`, `village/game_history.dart`, protocole Dart et relais en ligne si un événement partagé est nécessaire.

**Validation :** droits d'envoi et de réception, fréquence, reconnexion sans rejouer les anciennes réactions, absence d'information secrète dans les messages réseau publics. Réutiliser le pack de stickers téléchargeable.

## Lot 7 — Micro à maintenir en ligne

Ce lot introduit une fonction audio en direct. Un scheduler de notifications ou le WebSocket de jeu existant ne remplace pas le transport des voix.

### Expérience prévue

- [x] Micro coupé par défaut ; appui maintenu pour parler, relâchement pour couper.
- [x] Option explicite de verrouillage pour parler sans maintenir ; état actif évident et coupure en un toucher.
- [x] Indicateur sur la maison du locuteur, visible uniquement aux destinataires du canal.
- [x] Le MDJ ouvre/ferme la parole et peut rendre un joueur muet.
- [x] Jour : canal du conseil selon les droits du MDJ. Nuit : canal de meute uniquement pendant son appel et pour ses membres autorisés. Le MDJ peut assurer ses annonces.
- [x] Les éliminés ne parlent pas aux vivants. Aucun canal vocal supplémentaire de spectateurs dans cette première version.
- [x] Les annonces automatiques font baisser l'ambiance et suspendent la prise de parole pour rester compréhensibles ; le MDJ conserve son choix de narration automatique ou manuelle.
- [x] Couper l'émission au départ du salon, à la perte de connexion, à un changement de canal non autorisé ou au passage en arrière-plan. Préserver séparément l'état « prêt » existant.
- [x] Le vocal reste facultatif ; une panne audio laisse accessibles le jeu, les votes et le chat écrit.
- [x] En local, conserver le fonctionnement dans la même pièce, sans activer le micro réseau.

### Intégration à réaliser

1. Définir le contrat des canaux et des changements de droits à partir de l'état autoritaire du moteur Dart : salon, phase, vivants et appartenances réelles. Ne jamais faire confiance au rôle déclaré par un client.
2. Transport retenu : LiveKit autonome, avec client Flutter et contrôle FastAPI. Les sessions et permissions sont testées avec le moteur Dart réel et une API média simulée. Le prototype audio entre deux réseaux, les relais et la charge réelle restent à valider sur Contabo ; aucune capacité serveur n’est garantie sans cette mesure.
3. Ajouter à FastAPI la délivrance d'accès audio temporaires liés à une session de salon valide. Le code public du salon ne suffit pas. Les changements de phase, éliminations et exclusions doivent retirer effectivement les droits audio, pas seulement masquer le bouton.
4. Ajouter le service Flutter, les contrôles du micro, la demande d'autorisation au moment de l'utilisation et les messages de refus/récupération.
5. Préparer les fichiers de configuration et les instructions de déploiement sans exposer les secrets du transport dans l'application.

**Validation :** deux réseaux distincts, refus du micro, coupure/reconnexion, changement jour/nuit, élimination, exclusion et fermeture du salon ; tentative d'écoute ou d'émission dans un canal interdit ; charge avec plusieurs participants. Contrôler aussi que l'indicateur du locuteur ne dévoile jamais la meute au village.

La livraison B demande une mise à jour coordonnée du client, du backend et du moteur. Prévoir un indicateur de disponibilité du vocal pour les anciennes applications ; elles doivent recevoir un message compréhensible si une mise à jour devient nécessaire.

## Règles transversales de réalisation

- Séparer les événements de jeu des effets : une animation interrompue ne change pas le résultat du moteur.
- Utiliser les identifiants des événements pour éviter le rejeu des sons et cérémonies à la reconnexion.
- Éviter les indices publics liés à un rôle, une cible ou une discussion privée.
- Ne pas changer les prix, les collections, les règles des cartes ni les sentences originales fournies par Logan dans cette mise à jour.
- Documenter les fichiers réellement modifiés et les vérifications réellement exécutées à la fin de chaque lot.
- Préparer les changements localement ; Logan conserve le build APK et l'exécution des commandes sur Contabo.

## Suivi

| Lot | État au 2 novembre 2026 | Dépendance |
|---|---|---|
| 1. Carte et caméra | Corrections intégrées ; tests automatisés réussis ; essai téléphone attendu | Première étape |
| 2. Cartes et vibrations | Intégré et testé : maintien, masquage, ressort, inclinaison et préférences | Essai téléphone |
| 3. Matières et sons | Intégré : finitions, son générique et effets par cause préservés | Essai téléphone |
| 4. Village et hibou | Intégré : cheminées, lumières, vol courbe et ancrage caméra | Rendu et fluidité sur téléphone |
| 5. Packs et validation A | Réglages et réutilisation des packs intégrés ; contrôles automatisés réussis | Build et validation Logan |
| 6. Réactions et grimoire | Intégré et testé : réactions privées/publiques temporaires et chapitres | Essai en partie |
| 7. Vocal | Client, droits, backend et installation préparés ; média réel non validé | Déploiement Contabo et deux réseaux |

Les préférences, la sobriété des effets et la gestion des packs s'appliquent dès chaque lot ; le lot 5 vérifie leur cohérence d'ensemble.

Prochaine étape : **validation de Logan sur téléphone, puis activation du média sur Contabo avec le guide fourni**. Les cases ci-dessus décrivent le plan initial ; le tableau de suivi et le bilan distinguent l’intégration des validations restantes.

## Évolution réservée pour plus tard

[Mode Enquête nocturne](propositions/enquete-nocturne.md) : proposition de déplacements secrets, lieux et observations, archivée le 2 novembre 2026. Reportée à une future mise à jour à la demande de Logan.
