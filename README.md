# Mordeviel

**Legendary** — sous-titre du jeu. Identité retenue : **Mordeviel**.
Application, vitrine, emails, logo et icônes utilisent ce nom. Le domaine public
reste `https://mordeviel.newtechnologiestg.com`.
Voir [le récapitulatif du renommage](docs/changement-nom-mordeviel.md).

Jeu de loup-garou animé par un maître du jeu, en réseau local ou à distance.

## Prérequis

Flutter stable (initialisé avec 3.44.5 / Dart 3.12.2), Python 3.12+, Git.
Android nécessite le SDK Android ; les builds iOS nécessitent macOS et Xcode.

Sur la machine initiale, `flutter doctor` détecte Flutter, Chrome et Visual Studio.
Le SDK Android est déjà installé dans `C:\Users\hp\AppData\Local\Android\Sdk`,
comme pour Tradecare, avec les plateformes 33 à 36, le NDK et un fichier de licence.
`flutter doctor` signale néanmoins l'absence de Command-line Tools et ne peut
pas déterminer le statut des licences. Cela ne signifie pas que le SDK est absent.
La compilation Android de ce nouveau projet doit encore être validée.

L'environnement `backend/.venv` a été créé avec Python 3.12.14 fourni par Codex.
Il n'est pas versionné et doit être recréé sur chaque machine.

## Flutter

```powershell
cd apps/mordeviel
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Pour un téléphone physique, remplacer 127.0.0.1 par l'adresse LAN du serveur.
Pour l'émulateur Android, utiliser 10.0.2.2. Cette configuration est affichée
dans l'écran initial ; cette URL concerne uniquement le futur mode distant.

## Essayer le salon local

1. Lancer l'application native sur les appareils connectés au même Wi-Fi.
2. Sur l'hôte : **Jouer en local**, saisir le pseudo, puis **Créer un salon**.
3. Sur les invités : saisir pseudo, adresse `IP:port` affichée par le MDJ et code à six chiffres.
4. Le MDJ règle la composition : une carte par joueur, au moins 4 joueurs hors MDJ,
   au moins un loup et une majorité de membres du Village. Les rôles spéciaux sont uniques.
5. Chacun consulte **Codex et règles de la partie** et active **Je suis prêt**.
   Modifier la composition ou le réglage Voyante annule les confirmations.
6. Le MDJ utilise **Lancer et distribuer les rôles**, puis confirme.
   Chaque joueur ouvre **Consulter ma carte secrète**. La vue MDJ contient les attributions.

Le port est attribué automatiquement et peut changer à chaque création.
Le MDJ reste hors de la liste des joueurs. Son écran reste allumé pendant
l'hébergement ; l'application doit rester au premier plan. Les QR codes,
la sauvegarde persistante et la reprise automatique ne sont pas encore implémentés.
Après distribution, un joueur déconnecté utilise **Se reconnecter** sur le même écran :
un jeton privé lui rend sa place et sa carte. Ne pas fermer l'application ni quitter
cet écran : le jeton est conservé en mémoire uniquement. Si le MDJ ferme le salon
ou son application, la partie n'est pas restaurable. Avant distribution, une
reconnexion réinscrit le joueur, non prêt, si les inscriptions restent ouvertes.
Les messages du salon LAN circulent en clair sur le réseau de confiance.
Le pare-feu Windows doit autoriser l'application si l'hôte est un PC.
Les réseaux invités peuvent empêcher les appareils de communiquer.
Le salon local est réservé aux applications natives ; le web affiche une explication.

## Backend (depuis la racine)

```powershell
python -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -e './backend[dev]'
backend/.venv/Scripts/python.exe -m uvicorn mordeviel_api.main:app --reload --host 0.0.0.0
```

API : http://127.0.0.1:8000/docs — diagnostic : http://127.0.0.1:8000/health.
L'écoute sur toutes les interfaces est destinée au développement sur un réseau de confiance.

Les versions Python résolues sur Windows sont consignées dans
`backend/requirements-dev.lock.txt`. Pour reproduire cet environnement : installer
ce fichier avec `pip install -r backend/requirements-dev.lock.txt`, puis le backend
avec `pip install --no-deps -e ./backend`. Ce relevé inclut des dépendances Windows.

## Vérification

```powershell
backend/.venv/Scripts/python.exe -m pytest backend/tests
backend/.venv/Scripts/python.exe -m ruff check backend
cd apps/mordeviel
flutter analyze
flutter test
```

Le script `scripts/setup.ps1` prépare les dépendances depuis la racine.
Diagnostic du serveur local (depuis la racine) :
`dart packages/local_host/tool/smoke.dart`.
Test du salon multijoueur : `dart packages/local_host/tool/lobby_smoke.dart`.
Test du client Flutter/Dart : `dart packages/local_host/tool/client_smoke.dart`.
Distribution et confidentialité : `dart packages/local_host/tool/deal_smoke.dart`.
Reprise du client : `dart packages/local_host/tool/resume_smoke.dart`.
Connexions concurrentes et contrôles de présence :
`dart packages/local_host/tool/concurrent_smoke.dart`.

## Diagnostic réseau

Le MDJ peut ouvrir **Diagnostic des connexions** pour consulter les dernières
arrivées et les déconnexions avec leur code. Ce journal reste sur son appareil,
ne contient ni jetons de session ni rôles, et n'est pas envoyé aux joueurs.
Le serveur pilote le contrôle WebSocket toutes les 30 secondes ; le client
ne lance pas de second minuteur de ping. Les erreurs de transport sont conservées
dans le message de déconnexion, sans être écrasées par une notification générique.

Pour un émulateur Android rejoignant un MDJ Windows sur la même machine,
utiliser `10.0.2.2:PORT` (le port affiché par le MDJ). Pour les téléphones
physiques, utiliser l'adresse LAN affichée. L'émulateur n'est pas un téléphone
physique sur le Wi-Fi : son accès au PC passe par un réseau virtuel.

Un test Android contre un salon de développement ouvert est disponible :

```powershell
cd apps/mordeviel
flutter test integration_test/network_test.dart -d emulator-5556 --dart-define=TEST_HOST=10.0.2.2:PORT --dart-define=TEST_ROOM_CODE=CODE
```

Ce test ajoute deux clients temporaires, vérifie les mises à jour et le statut
prêt après 25 secondes d'inactivité, puis les ferme. Il compare l'ancien double
ping avec le contrôle serveur seul. Sur l'émulateur Android testé contre le
salon Windows, l'ancien fonctionnement a fermé les deux connexions (code 1001),
tandis que le contrôle serveur seul a réussi. Le test nécessite un salon qui
ne soit pas déjà en partie.

## Cartes et ambiance

Depuis l'accueil, **Découvrir les cartes** ouvre les cinq rectos fournis.
**Retourner la carte** effectue une rotation pour afficher les règles détaillées,
en texte Flutter défilant ; **Cacher la carte** la fait sortir vers le bas.
Un balayage rapide vers le bas sur le recto permet aussi de la masquer.
En cas de perte du premier plan, son contenu est immédiatement masqué.
Les préférences système de réduction des animations sont respectées.

Les rectos originaux (textes compris) sont conservés. Les corrections de règles
de la Sorcière et du Chasseur sont expliquées au verso. Cette galerie est un
aperçu public des rôles possibles, pas une attribution de rôle en partie.
Les trois bordures peuvent être prévisualisées au verso, sans boutique ni achat.
Les décors portrait et paysage sont utilisés séparément ; le montage cumulé
n'est pas utilisé. Les sources originales restent dans `mordeviel/` ; les copies
embarquées sont dans `apps/mordeviel/assets/`.

L'harmonisation des illustrations elles-mêmes (style du Villageois, compagnon
du Chasseur, ornements des cadres) n'a pas été effectuée : les images restent
intactes. Les mentions du camp et du moment d'action sont explicites au verso.

## Essayer la première nuit

Après distribution, le MDJ choisit 60, 120 ou 180 secondes par appel, puis
**Endormir le village**. Il déclenche ensuite les appels dans l'ordre :
Voyante (si incluse), Loups-Garous, Sorcière (si incluse), réveil, puis Chasseur
s'il figure parmi les victimes. Les rôles configurés continuent d'être appelés
même s'ils sont morts : cela évite de révéler leur identité par un appel absent.

Chaque joueur voit la même annonce. Seuls les rôles autorisés reçoivent leurs
commandes privées. La meute dispose d'un chat textuel limité à son appel et
visible également du MDJ. Un choix de victime peut être modifié jusqu'à la
clôture ; sans unanimité de tous les loups vivants, aucune attaque n'a lieu.
La Voyante et la Sorcière confirment une seule action par appel. La Sorcière
peut confirmer sans utiliser de potion. Les potions consommées restent consommées.

Le MDJ peut mettre le chronomètre en pause et reprendre, ou clore un appel
avec confirmation. À l'échéance, les commandes se ferment ; le MDJ déclenche
toujours le passage suivant. Les absences de réponse ne déclenchent aucun
pouvoir automatique. Le Chasseur a 60 secondes pour sélectionner sa cible ;
le MDJ peut suspendre cet appel ou poursuivre sans tir s'il ne répond pas.
La victoire est vérifiée après toutes les réactions, jamais avant le dernier tir.

La reconnexion rend le rôle, les ressources et la vision privée déjà obtenue.
Les anciens messages d'action d'un autre appel sont refusés grâce à une révision
de phase. Les échéances et les résultats font autorité sur le serveur.

Le débat et le vote permettent maintenant d'enchaîner plusieurs journées et
nuits jusqu'à la victoire. La carte interactive du village est disponible.
Les appels vocaux et les sons d'ambiance restent à ajouter. Les annonces sont
textuelles ; aucune voix n'est diffusée en local.
Pour mettre à jour une installation Android, installer le nouvel APK sur chaque
appareil. Redémarrer MDJ et joueurs puis recréer un salon après cette mise à jour.

Tests : `dart packages/local_host/tool/night_smoke.dart` (règles et cas limites),
`dart packages/local_host/tool/night_network_smoke.dart` (nuit complète et secrets sur WebSocket).

## Débat et vote de jour

Au réveil, après les éventuelles réactions du Chasseur, le MDJ ouvre la journée.
Les survivants discutent dans le chat général ; le MDJ peut le fermer ou le rouvrir.
Les joueurs éliminés suivent le débat mais ne peuvent ni écrire ni voter.
Le MDJ choisit une durée parmi 30/60/120/180/300 secondes puis ouvre le scrutin.
Il peut suspendre le chronomètre, le reprendre et clore le vote avant l'échéance
avec confirmation. À l'échéance les bulletins sont verrouillés ; il révèle les
résultats avec **Clore et révéler le scrutin**.

Chaque survivant peut désigner un survivant (lui-même compris) ou voter blanc,
puis modifier son bulletin jusqu'à la clôture. L'absence de bulletin est une
abstention. Un vote blanc seul en tête, une égalité (y compris avec le blanc)
ou l'absence de tout bulletin n'élimine personne. Le vote est à la pluralité :
une cible seule en tête est éliminée, même sans majorité absolue des inscrits.

Les totaux sont révélés ensemble à la clôture ; les bulletins individuels restent
privés. Un bulletin reçu reste conservé après une coupure et est rendu à son
auteur à la reconnexion. La mort du Chasseur déclenche son tir avant toute
vérification de victoire. Si aucun camp ne gagne, **Commencer la nuit suivante**
relance le cycle avec les mêmes rôles et ressources restantes.

Tests : `dart packages/local_host/tool/day_smoke.dart` (règles de vote et boucle)
et `dart packages/local_host/tool/day_network_smoke.dart` (chat, confidentialité,
reconnexion, décompte, élimination et deuxième nuit avec quatre clients).

## Village et cérémonies

Le salon affiche la map fournie avec une maison par joueur (20 maximum).
Le serveur attribue un `house_slot` stable : une déconnexion en partie conserve
la maison, le rôle et l'état d'élimination. Avant distribution, quitter libère
l'emplacement. Le décor possède 24 parcelles fixes ; les parcelles non utilisées
restent visibles, sans maison. La vue téléphone est centrée et agrandie ; le
bouton **Vue d'ensemble** montre le terrain complet. Pincer, déplacer et les
boutons +/− permettent de naviguer. Le cadre du fond fourni suit actuellement le zoom.

Les trois PNG de maison sont recadrés uniquement à l'affichage pour aligner
leurs silhouettes. Les sources restent intactes. Le jeu déclenche la transition
jour/nuit, les fenêtres éclairées et la maison de deuil. Toucher une maison ouvre
sa fiche ; les rôles vivants restent secrets aux autres joueurs.

Des bulles apparaissent au-dessus des auteurs dans la discussion autorisée :
générale le jour, meute pendant son appel (loups vivants et MDJ seulement).
Toucher une bulle ouvre un panneau coulissant, mis à jour en direct. Le clavier
et les petits écrans disposent d'un affichage défilant.

À la préparation, **Révéler les cartes à l'élimination** est activé par défaut.
Le Codex affiche ce choix ; le changer annule les confirmations des joueurs.
Une annonce d'élimination retourne la carte, puis applique des griffures pour
une mort nocturne. Toutes les morts de nuit partagent cette présentation, sans
révéler si la cause précise était une attaque ou une potion. En mode secret,
les autres voient le dos de carte ; la victime garde accès à sa propre carte.
Un événement est présenté une fois par appareil, avec reprise des annonces
manquées lors d'une reconnexion sur le même écran. Les cartes privées se
présentent aussi face cachée avant **Découvrir ma carte**.

Après une élimination au vote, le MDJ peut lancer la roue classique à huit
secteurs. Le serveur choisit une seule sentence et transmet le même résultat
à tous, avec une durée d'animation de 4,5 secondes. Il n'existe pas de second
tirage. La roue est cosmétique : elle ne change ni décès, ni ressources, ni
victoire. Si elle tourne, le MDJ attend sa fin avant de poursuivre ; les choix
du Chasseur restent possibles. Aucun tirage en cas d'égalité ou de vote blanc.
Un bouton de reprise est affiché directement sous la sentence : **Commencer
la nuit suivante**, **Reprendre le dernier tir du Chasseur** ou **Voir le résultat
de la partie** selon la phase. Il s'active à la confirmation serveur de fin
d'animation et conduit aux commandes correspondantes sans les chercher plus bas.
Le passage à la nuit conserve la durée des appels choisie par le MDJ.
Les peaux premium et scènes d'exécution ne sont pas implémentées.

Les assets sont dans `apps/mordeviel/assets/village/`, copiés depuis `mordeviel/Map/`.
Les animations respectent la réduction des animations du système. Les PNG de
petite définition conviennent au prototype et pourront être remplacés à l'identique.
Tests dédiés : `flutter test test/village_test.dart` et
`dart packages/local_host/tool/ceremony_smoke.dart`.

## État de l'implémentation

Salon Flutter relié au serveur local Dart : arrivées/départs, statut prêt,
fermeture des inscriptions et retrait par le MDJ. Tests WebSocket exécutés sur
ordinateur ; compilation Windows debug réussie. Validation sur téléphones
physiques encore nécessaire. Exécutable local :
`apps/mordeviel/build/windows/x64/runner/Debug/mordeviel.exe` (conserver les DLL et le
dossier `data` à côté ; ne pas distribuer uniquement le fichier EXE).
La composition, le Codex, la distribution privée et la reprise de rôle après
coupure sont implémentés en LAN. L'API distante conserve uniquement son diagnostic.
Les appels, actions nocturnes, discussions de jour, votes et transitions vers
les nuits suivantes sont implémentés en LAN. Le moteur peut terminer une partie
et dévoiler les rôles. Le village, les états des maisons et les cérémonies sont
intégrés. Le vocal, les packs commerciaux et
la sauvegarde persistante ne sont pas encore implémentés.
Voir `docs/architecture.md`.
