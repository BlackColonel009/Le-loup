# Vérification avant build — 27 octobre 2026

## Résultat

Vérification effectuée après la carte Intense v3 (base Git `923546e`).
Les contrôles ci-dessous ont réussi. Aucun défaut bloquant du moteur des rôles
ou des échanges n'a été reproduit dans ces scénarios. Une correction du banc
de tests Flutter a été nécessaire : le test d'accès administrateur utilise
maintenant un stockage sécurisé simulé, comme les tests de connexion.

| Contrôle | Résultat |
| --- | --- |
| Suite Flutter complète | 131 tests réussis |
| Suite FastAPI complète avec moteur Dart disponible | 15 tests réussis |
| Scénarios Dart existants | 16 programmes réussis |
| Partie de contrôle sur Contabo en HTTPS/WSS | 20 clients, 17 rôles, deux nuits et un jour complet |
| Analyse statique du moteur et du nouveau scénario en ligne | Aucune anomalie |

Aucun APK ni exécutable de l'application n'a été compilé. Les emails des tests
backend sont simulés ; aucun email réel n'a été envoyé. La partie de contrôle
en ligne a utilisé un salon dédié avec uniquement des joueurs de test, fermé
dans le bloc de nettoyage du scénario.

## Rôles vérifiés

Les cinq rôles de base sont couverts par `night_smoke.dart`, `day_smoke.dart`
et leurs équivalents réseau. Les douze rôles supplémentaires sont couverts par
`expanded_roles_smoke.dart` et `expanded_network_smoke.dart`.

| Rôle | Comportement vérifié |
| --- | --- |
| Villageois / Villageoise | Débat et vote, absence de pouvoir nocturne, apparence sans changement de règle |
| Loup-Garou | Accord unanime, réponse manquante/désaccord, cibles autorisées, chat privé |
| Voyante | Vision privée, rôle exact ou camp, une action par nuit, refus des autres joueurs |
| Sorcière | Potions uniques, deux potions la même nuit, information liée à la potion de vie, sauvetage et poison |
| Chasseur | Réaction après mort, cible vivante, contrôle de victoire après son tir |
| Petite Fille | Murmure anonyme, un espionnage par nuit, détection privée à la meute |
| Métamorphe | Échange initial unique, rôles et notifications privés mis à jour, nouveaux pouvoirs utilisables |
| Cupidon | Choix initial, reconnaissance privée, mort de chagrin, réaction du Chasseur et victoire des amoureux |
| Salvateur | Protection de la meute, auto-protection, interdiction de reprendre la cible précédente, secret de la protection |
| Ancien | Première attaque absorbée, résistance consommée, perte des pouvoirs du Village après élimination concernée |
| Bouc émissaire | Égalité au vote, réaction après élimination, restriction des électeurs pour un seul jour |
| Alpha | Seconde cible distincte, désactivation après la mort d'un membre de la meute |
| Loup Blanc | Présence dans la meute, attaque personnelle les nuits paires, victoire solitaire |
| Père des Loups | Infection à usage unique, activation différée, annulation par la potion de vie, conservation du rôle |
| Idiot | Grâce au vote et perte du droit de vote |
| Joueur de Flûte | Cibles non charmées, information privée des charmés, victoire personnelle et changement d'objectif après infection |
| Ange | Victoire au premier vote, transformation en Villageois s'il échoue en survivant |

Les rôles spéciaux sont uniques dans une composition acceptée par le serveur.
Les éditions Classique et Intense partagent le même moteur ; leur apparence
ne modifie pas les pouvoirs. Le thème Horreur n'est pas encore sélectionnable
comme pack de partie dans le moteur actuel.

## Échanges et réseau

- Arrivées simultanées, pseudos, état prêt et vingt emplacements de maison distincts.
- Distribution privée, séparation des informations publiques et de la vue MDJ.
- Autorisations des actions, rejet des actions d'un autre rôle et des anciennes phases.
- Chat nocturne des loups limité au réveil de la meute, absent chez les autres joueurs.
- Effacement des messages nocturnes après l'appel et avant la nuit suivante.
- Chat de jour partagé, fermeture par le MDJ, refus d'écriture aux morts.
- Bulletins privés avant clôture, changement de vote, blanc, égalité, abstention.
- Chronomètre, pause, reprise, fin de délai et contrôle des appels nocturnes par le MDJ.
- Maintien de l'identité et du rôle après reconnexion ; le joueur rejoint bien à nouveau le salon.
- Sentence identique entre les clients et poursuite de la partie après la roue.

La partie publique a exercé notamment l'échange Métamorphe/Voyante, les amoureux,
la protection, une vision, le chat des loups et l'espionnage, l'Alpha, une infection
annulée par la Sorcière, le charme, un décès nocturne, le vote du Chasseur, la mort
de son amoureux, son tir, la roue, puis la nuit suivante avec la résistance de
l'Ancien et l'attaque du Loup Blanc. Les pouvoirs non déclenchés dans cette seule
partie restent couverts par les scénarios de moteur séparés.

## Reproduire

Depuis `apps/mordeviel` :

```powershell
flutter test --no-pub
```

Depuis la racine du dépôt :

```powershell
$env:MORDEVIEL_DART = 'C:\bibliotheque\flutter\bin\cache\dart-sdk\bin\dart.exe'
backend/.venv/Scripts/python.exe -m pytest backend/tests -q
```

Depuis `packages/local_host`, exécuter les programmes `tool/*_smoke.dart`
(sauf `online_client_smoke.dart`, qui demande un serveur), ainsi que `tool/smoke.dart`.
Le fichier `classic_scenario_driver.dart` est un utilitaire, pas un programme autonome.

Pour rejouer la grande partie de contrôle :

```powershell
dart run tool/full_online_audit.dart https://mordeviel.newtechnologiestg.com
```

Cette commande crée un salon et vingt clients simulés puis les ferme. Lancer
avec une capacité disponible sur le serveur ; aucun salon existant n'est utilisé.

## Limites pratiques

Ces contrôles vérifient le code et les transports réellement utilisés, avec
des clients simulés sur ordinateur. Ils ne constituent pas un essai matériel
de vingt téléphones Android, une mesure de performances sur chaque appareil,
ni une validation du comportement d'un téléphone hôte mis en arrière-plan.
Après le build, installer l'APK sur les téléphones pour confirmer le rendu,
l'audio et les connexions dans les conditions réelles de la partie.

## Ajout des cérémonies — 27 octobre 2026

- Suite Flutter complète : **147 tests réussis**, dont les sept résultats de
  victoire, les dernières paroles, leur ordre de lecture, le silence général,
  l’annulation au départ du salon et les cartes secrètes.
- Analyse Dart ciblée : aucune anomalie sur les fichiers des cérémonies.
- Après harmonisation de la police des cartes Intense : 13 tests ciblés réussis.
- Captures réelles du rendu Flutter : Village, Loups et malédiction de l’Ancien,
  sous `apps/mordeviel/build/previews/` (fichiers de travail non publiés).
- Treize nouveaux WAV neuronaux, intégrité vérifiée et déclaration Flutter
  générée, plus deux jingles originaux. Contrôle de contenu par transcription
  locale consigné dans `audio-auditions/events-transcription-checks.json` ;
  quelques confusions phonétiques du transcripteur sur les voix de personnages
  restent à apprécier à l’écoute. Aucun usage de synthèse Windows.
- Aucun changement du backend ou des règles ; aucun build APK exécuté.

Détails fonctionnels : `ceremonies-fin-partie.md`.

## Historique, sélections et 17 dernières paroles — 28 octobre 2026

- **155 tests Flutter réussis**, dont une partie complète sur deux manches avec
  potions, visions, votes modifiés, confidentialité avant la fin et copies du
  journal sans accès aux objets du moteur.
- **16 programmes de contrôle Dart réussis** : rôles, transports locaux,
  reprise, concurrence, votes, nuit, QR, météo et cérémonies.
- Les tests de sélection distinguent brouillon et confirmation serveur, avec
  auteur et cible, et les deux potions du MDJ.
- Deux éliminations successives vérifiées : affichage de la réplique, une voix
  par révélation, arrêt au glissement et passage à la suivante.
- Tous les rôles ont un WAV déclaré, plus la Villageoise et la malédiction de
  l’Ancien. Contrôle ASR mis à jour ; les confusions phonétiques sur les voix
  stylisées ne constituent pas une validation d’écoute.
- Mise à jour du moteur serveur nécessaire pour le nouvel historique en ligne.
  Pas de migration ni nouvelle dépendance. Aucun APK compilé.

## Ombres et narration commune — 28 octobre 2026

- **164 tests Flutter réussis**, y compris l’existence et le texte exact des 280
  annonces. **15 tests backend** et **17 contrôles moteur/réseau Dart réussis**.
- Ombres vertes au sol dans le salon pour les joueurs prêts ; disparition à la
  distribution. Ombres rouges sous les maisons des éliminés, dans les deux thèmes.
  Captures du rendu réel vérifiées, avec un dégradé elliptique diffus.
- 280 annonces du MDJ : 28 textes identiques dans chacun des dix profils validés.
  Empreintes et formats vérifiés ; 328 fichiers neuronaux déclarés au total.
  Les 280 annonces ont un contrôle de transcription locale, avec empreinte,
  dans `audio-auditions/narration-transcription-checks.json`. Les confusions
  phonétiques du transcripteur sur les voix stylisées restent distinctes d’une
  appréciation artistique à l’écoute.
- Profil et mode automatique partagés par le moteur. Contrôle sur quatre
  clients WebSocket, puis derrière FastAPI : paramètres reçus par tous, sans
  accès aux données privées et sans perte des rôles.
- Réactivation sans relire le passé ; reconnexion sur le dernier appel seulement ;
  aucune vieille annonce au retour sur une partie déjà terminée.
- Les répliques de personnages gardent leur voix dédiée et les volumes restent
  personnels. Les sons locaux restent exclusivement chez le MDJ.
- Les tests backend attendent désormais la fermeture des WebSockets avant de
  démonter leur contexte, pour éviter une course de fermeture du test.
- Aucune compilation APK. La mise à jour en ligne nécessite un pull puis le
  redémarrage du service `mordeviel`, sans migration ni nouvelle dépendance
  Python/Dart sur le serveur.

Voir `statuts-maisons.md`, `voix-parametrables.md` et `textes-voix-off.md`.
