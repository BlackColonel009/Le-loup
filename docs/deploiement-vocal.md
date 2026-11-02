# Vocal en direct — installation Contabo

Préparé le 2 novembre 2026 pour le serveur existant `/var/www/Le-loup`, le service `legendeofwolf` et le domaine `mordeviel.newtechnologiestg.com`.

## Fonctionnement

Le moteur Dart calcule les droits. FastAPI vérifie la session privée du salon et signe un accès audio court. LiveKit relaie les voix ; il ne remplace ni FastAPI, ni le moteur Dart, ni le scheduler de notifications. Aucun compte LiveKit Cloud ou Firebase n'est requis pour cette configuration.

Le vocal est désactivé par défaut dans chaque nouveau salon. Le MDJ l'active dans « Contrôle vocal du MDJ ». Chaque joueur choisit ensuite « Rejoindre le vocal ». Un maintien ouvre le micro, le relâchement le coupe ; le cadenas permet de rester en émission. Le changement de phase, le départ, la perte de connexion ou la mise en arrière-plan retirent cet état. Ouvrir le clavier masque les commandes vocales pour laisser la place au chat et coupe un éventuel micro verrouillé, sans interrompre l'écoute.

Au conseil, les vivants parlent selon les autorisations du MDJ et les spectateurs écoutent. Pendant l'appel des loups, seuls les membres actuels de la meute et le MDJ disposent du canal privé. Les autres n'en reçoivent ni le jeton ni les indicateurs de parole. Hors de cet appel, un canal d'annonces permet d'écouter le MDJ pendant la nuit. Les annonces automatiques continuent sur chaque téléphone comme auparavant ; la narration coupe temporairement la prise de parole. Il n'y a pas de vocal réseau dans le mode local.

## Préparer les fichiers sur le serveur

Prérequis : Docker Engine et la commande `docker compose` doivent être disponibles. Le projet conserve Python et Dart comme avant. Référence d'installation : [Docker sur Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

Exécuter depuis la racine du projet :

```bash
cd /var/www/Le-loup
git pull
backend/venv/bin/python -m pip install -e ./backend
backend/venv/bin/python tools/deploy/prepare_voice.py
docker compose -f tools/deploy/voice.compose.yaml config --quiet
docker compose -f tools/deploy/voice.compose.yaml up -d
```

`prepare_voice.py` ajoute uniquement les réglages vocaux manquants dans `backend/.env`. Il conserve les réglages SMTP et les clés déjà définies, génère les nouvelles clés sans les afficher, et produit `backend/data/livekit/livekit.yaml`. Le dossier de données et `.env` sont ignorés par Git. Le script est réexécutable sans renouveler les clés existantes.

Il réutilise le certificat Let's Encrypt du domaine public, monté en lecture seule dans le conteneur. Adapter le domaine configuré dans `MORDEVIEL_PUBLIC_URL` avant d'exécuter le script si le site change d'adresse.

Les quatre paramètres backend sont :

```dotenv
MORDEVIEL_VOICE_URL=wss://mordeviel.newtechnologiestg.com
MORDEVIEL_VOICE_API_URL=http://127.0.0.1:7880
LIVEKIT_API_KEY=valeur-privee-generee
LIVEKIT_API_SECRET=valeur-privee-generee
```

Ne pas recopier les valeurs d'exemple des clés. Elles restent exclusivement côté serveur.

## Relier Nginx sans nouveau DNS

Dans le bloc **HTTPS existant** du domaine, ajouter :

```nginx
include /var/www/Le-loup/tools/deploy/voice.nginx.conf;
```

Le fichier habituel de ce serveur est `/etc/nginx/sites-available/legendeofwolf`. Le bloc qui contient cette ligne doit correspondre à `server_name mordeviel.newtechnologiestg.com` et à l'écoute HTTPS sur 443. Conserver les routes actuelles vers FastAPI.

```bash
sudo nano /etc/nginx/sites-available/legendeofwolf
sudo nginx -t && sudo systemctl reload nginx
sudo systemctl restart legendeofwolf
```

Le SDK utilise `/rtc` et ses sous-chemins sur le même domaine. Le fragment Nginx les dirige vers LiveKit ; le site, les comptes et les salons restent sur FastAPI.

## Ports nécessaires

| Port | Usage |
|---|---|
| 443/TCP existant | Site HTTPS et signalisation vocale WSS via Nginx |
| 7881/TCP | Repli média WebRTC sur TCP |
| 50000–50199/UDP | Médias WebRTC |
| 3478/UDP | Relais TURN |
| 5349/TCP | Relais TURN avec TLS |
| 7880 | API LiveKit, liée à `127.0.0.1`, à conserver privée |

Si UFW est déjà utilisé, autoriser les ports média, ainsi que dans un éventuel pare-feu Contabo :

```bash
sudo ufw allow 7881/tcp
sudo ufw allow 50000:50199/udp
sudo ufw allow 3478/udp
sudo ufw allow 5349/tcp
```

Sur un réseau qui n'autorise strictement que TCP/443, le TURN/TLS sur 5349 peut être bloqué. Ce cas demande un relais TURN/TLS accessible sur 443 avec une adresse ou un routage supplémentaire. Il doit être vérifié avant de promettre la compatibilité avec tous les réseaux d'entreprise. Le jeu écrit reste disponible lorsque le vocal échoue.

## Contrôler l'installation

```bash
docker compose -f tools/deploy/voice.compose.yaml ps
docker compose -f tools/deploy/voice.compose.yaml logs --tail=50 livekit
sudo systemctl status legendeofwolf --no-pager
curl -fsS https://mordeviel.newtechnologiestg.com/health
```

La route `/health` vérifie l'API du jeu ; elle ne prouve pas que des paquets audio traversent les pare-feu. Pour valider le vocal : deux téléphones sur deux réseaux distincts, autorisation du microphone, maintien/relâchement, verrouillage, mute par le MDJ, passage jour/nuit, spectateur, reconnexion et arrière-plan. Vérifier que le villageois n'entend pas la meute et ne voit aucun indicateur provenant d'elle.

Le backend vérifie les autorisations avec le vrai moteur Dart dans les tests d'intégration. Le service média réel et les routes audio natives restent à valider après cette installation et le build de Logan. Docker est installé sur le PC de développement mais son moteur n'était pas démarré lors de ces contrôles ; aucun test de transport audio réel n'a été annoncé comme réussi.

## Certificats et redémarrage

Les certificats restent renouvelés par Certbot. Après un renouvellement, redémarrer LiveKit pour charger le nouveau certificat TURN :

```bash
cd /var/www/Le-loup
docker compose -f tools/deploy/voice.compose.yaml restart livekit
```

Cette commande peut être appelée par un hook de déploiement Certbot. Un redémarrage du média interrompt brièvement le vocal, avec reconnexion ; le moteur de jeu continue. Un redémarrage de `legendeofwolf` termine les salons en mémoire comme auparavant.

## Retrait des anciens accès

Les jetons sont valides 60 secondes pour rejoindre un canal précis et autorisent exclusivement le microphone, sans vidéo, données ou administration. Leur expiration ne suffit pas à expulser une connexion déjà établie. Chaque changement de permissions crée donc un nouvel identifiant aléatoire de canal et supprime le précédent via l'API média. `room.auto_create: false` empêche un ancien jeton de recréer un canal retiré. Ne pas activer la création automatique dans la configuration LiveKit.

Les accès ne contiennent pas d'email ni de pseudo de compte. Aucun enregistrement audio ni service d'enregistrement n'est configuré. Les journaux techniques du média utilisent des identifiants opaques de session.

Sources techniques : [installation LiveKit](https://docs.livekit.io/transport/self-hosting/deployment/), [jetons et restrictions de révocation en hébergement autonome](https://docs.livekit.io/frontends/reference/tokens-grants/), [API des salons](https://docs.livekit.io/reference/other/roomservice-api/), [configuration officielle](https://github.com/livekit/livekit/blob/master/config-sample.yaml), [version serveur retenue 1.13.11](https://github.com/livekit/livekit/releases/tag/v1.13.11).
