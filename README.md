# Le Loup

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
cd apps/le_loup
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
backend/.venv/Scripts/python.exe -m uvicorn le_loup_api.main:app --reload --host 0.0.0.0
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
cd apps/le_loup
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
cd apps/le_loup
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
n'est pas utilisé. Les sources originales restent dans `le_loup/` ; les copies
embarquées sont dans `apps/le_loup/assets/`.

L'harmonisation des illustrations elles-mêmes (style du Villageois, compagnon
du Chasseur, ornements des cadres) n'a pas été effectuée : les images restent
intactes. Les mentions du camp et du moment d'action sont explicites au verso.

## État du salon

Salon Flutter relié au serveur local Dart : arrivées/départs, statut prêt,
fermeture des inscriptions et retrait par le MDJ. Tests WebSocket exécutés sur
ordinateur ; compilation Windows debug réussie. Validation sur téléphones
physiques encore nécessaire. Exécutable local :
`apps/le_loup/build/windows/x64/runner/Debug/le_loup.exe` (conserver les DLL et le
dossier `data` à côté ; ne pas distribuer uniquement le fichier EXE).
La composition, le Codex, la distribution privée et la reprise de rôle après
coupure sont implémentés en LAN. L'API distante conserve uniquement son diagnostic.
Pas encore d'actions nocturnes, de votes, de vocal ou de partie complète jouable.
Voir `docs/architecture.md`.
