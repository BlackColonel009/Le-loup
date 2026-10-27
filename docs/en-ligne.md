# Version en ligne — première étape

La vitrine publique et son dashboard sont documentés dans [site-web.md](site-web.md).

FastAPI gère les salons et les accès publics. Un processus Dart par salon utilise
le moteur existant (17 rôles, packs, votes et réactions). Le moteur n'écoute que
sur 127.0.0.1 ; son port et ses commandes privées ne sont pas fournis aux joueurs.
Flutter conserve son mode local. L'entrée « Jouer en ligne » et le contrôleur
MDJ distant sont maintenant branchés dans les applications natives Android,
iOS et Windows. Le serveur public est accessible en HTTPS sur
`legendeofwolf.newtechnologiestg.com`. Le Web n'est pas
encore pris en charge par le transport Dart natif.

## Essayer depuis l'application

1. Utiliser le serveur public configuré par défaut, ou lancer FastAPI avec la
   commande ci-dessous pour tester un backend de développement.
2. Ouvrir **Jouer en ligne**, renseigner son pseudo et son apparence.
   Le MDJ choisit **Créer un salon**, puis copie l'invitation et le code.
   L'interface affiche le domaine public legendeofwolf.newtechnologiestg.com.
3. Les autres utilisent le code à six chiffres, puis
   **Rejoindre le village**. Les rôles, thèmes et commandes restent identiques
   au mode local. Le QR de réseau local n'est pas utilisé pour ce mode.
4. Après une coupure, **Reconnecter** reprend le MDJ ou le joueur tant que son
   écran et sa session en mémoire sont conservés. Fermer l'application efface
   le jeton privé ; il n'y a pas encore de récupération par compte.

L'adresse de l'API se configure avec `--dart-define=API_BASE_URL=https://...`.
Le formulaire n'expose pas ce réglage technique. L'invitation copiée contient
le vrai site public, le code du salon et les instructions pour rejoindre dans
l'application. Elle ajoute le lien de téléchargement actif de `/site-config`,
y compris la clé MEGA après `#`. Si les téléchargements sont désactivés ou le
service temporairement inaccessible, le site et le code sont conservés.
Sans configuration, l'application utilise le serveur public
https://legendeofwolf.newtechnologiestg.com pour les salons, la communauté et la
boutique. La valeur commune est définie dans
`apps/le_loup/lib/services/server_config.dart`.
Pour tester un backend de développement sur un téléphone, remplacer
`API_BASE_URL` par l'IP accessible
du PC (par exemple http://192.168.1.10:8000), sur un émulateur Android
http://10.0.2.2:8000. Cela permet les essais avant hébergement. Pour deux réseaux
différents, il faut une adresse HTTPS publique du serveur.

Les voix et l'ambiance sont jouées sur chaque appareil en ligne ; en local,
elles restent réservées au MDJ. Aucun appel vocal ni accès microphone n'est
ajouté à cette étape.

## Lancer le backend depuis la racine du dépôt

```powershell
$env:LE_LOUP_DART = 'C:\bibliotheque\flutter\bin\cache\dart-sdk\bin\dart.exe'
backend/.venv/Scripts/python.exe -m uvicorn le_loup_api.main:app --host 0.0.0.0 --port 8000
```

Les dépendances sont dans backend/pyproject.toml, dont websockets. Le serveur de
jeu nécessite Python et Dart ; Flutter SDK n'est pas nécessaire en hébergement
si le binaire Dart est installé. Sous Linux, définir LE_LOUP_DART avec son chemin
ou fournir dart dans PATH. Conserver packages/local_host avec le backend.

Utiliser **un seul worker Uvicorn**, les salons sont en mémoire. Le redémarrage du
backend termine les parties. Par défaut : 16 salons simultanés, durée maximale
6 heures. Configurables par LE_LOUP_MAX_ROOMS et LE_LOUP_ROOM_LIFETIME (secondes).
Le MDJ peut se reconnecter avec son jeton tant que son salon existe ; sa coupure
ne détruit pas la partie. Une seule connexion MDJ active est acceptée.

## Contrat

1. POST /rooms avec {"nickname":"Logan"} renvoie code, host_token, player_path
   et host_path. Le jeton MDJ est privé et n'est jamais envoyé aux joueurs.
2. WebSocket /rooms/{code}/host : premier message {"token":"…"}. Le serveur
   envoie {"type":"host.snapshot","room":{…}} avec les attributions privées.
3. WebSocket /rooms/{code}/ws : protocole joueur existant, par exemple
   {"version":1,"type":"room.join","code":"123456","nickname":"Alice",
   "appearance":"female"}. Seuls les états publics et les secrets du destinataire
   sont relayés. room.resume reprend une session grâce au jeton joueur.
4. Le client Dart accepte désormais une URL ws:// ou wss:// complète vers ce
   chemin, en plus des adresses LAN IP:port existantes.

Les commandes MDJ ont un champ action : configure, lock, kick, start,
night.start, night.call, night.advance, night.finish, pause, resume, vote.start,
day.chat, sentence.spin, sentence.continue, snapshot, room.close.
configure accepte deck, camp_only, pack et les réglages existants. Les commandes
de phase sont toujours validées par le moteur Dart. request_id est optionnel et
retourné dans command.ok ou error. Les événements host.snapshot arrivent aussi
en parallèle des réponses aux commandes.

## Déploiement et tests

L'accès Internet devra passer par HTTPS/WSS avec un reverse proxy, sans exposer
les ports internes Dart. Les clients natifs ne fournissent pas d'Origin ; pour
un futur navigateur, les origines autorisées seront listées explicitement dans
LE_LOUP_ALLOWED_ORIGINS, séparées par des virgules. Ni appels vocaux ni sauvegarde
persistante ne sont ajoutés à cette étape.

```powershell
$env:LE_LOUP_DART = 'C:\bibliotheque\flutter\bin\cache\dart-sdk\bin\dart.exe'
backend/.venv/Scripts/python.exe -m pytest backend/tests -q
```

Le test d'intégration utilise réellement le moteur Dart derrière FastAPI :
création, rejet d'un faux MDJ, pack partagé, quatre joueurs, distribution privée,
appels nocturnes et reconnexion. Sans LE_LOUP_DART, ce test est explicitement sauté.

`packages/local_host/tool/online_client_smoke.dart` teste le client Dart réel
contre un serveur démarré : création par OnlineHost, quatre LobbyClient, partage
Intense, commandes et reprise MDJ/joueur. Il accepte l'URL du serveur en argument.
