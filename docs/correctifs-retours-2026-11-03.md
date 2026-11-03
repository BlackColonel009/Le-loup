# Retours de parties — 3 novembre 2026

## Vocal et appels du MDJ

Le client conserve sa connexion média lorsqu’un nouvel état du jeu arrive mais que le canal autorisé reste identique. Les opérations de connexion/déconnexion sont ordonnées pour qu’une ancienne déconnexion ne coupe pas une nouvelle connexion. Si un appel change pendant une requête d’accès, le client recharge immédiatement les droits courants au lieu d’attendre le prochain poll. Une erreur réseau temporaire coupe le micro mais ne détruit pas une écoute encore saine ; un refus d’authentification ferme l’accès.

Le serveur ne renouvelle plus l’identifiant du salon LiveKit à chaque révision de phase ou pendant la pause locale des voix off. L’identité du canal dépend des permissions réelles du moteur. Les changements de droits réels continuent de retirer les anciens salons, notamment lors du passage au canal secret des loups : les protections du déploiement auto-hébergé sont conservées. Le jeton transporte les permissions du jeu ; le champ `publish` de la réponse et la lecture audio locale contrôlent la pause de parole pendant les annonces. Une simple annonce ne force donc plus toute la table à se reconnecter.

Les appels répétés à `CreateRoom` sont espacés et les salons vides gardent une marge de reprise. Les autorisations restent calculées à partir du rôle actuel et de la session du joueur. Le comportement des jetons auto-hébergés est décrit dans la [documentation officielle LiveKit](https://docs.livekit.io/frontends/reference/tokens-grants/).

Les notifications vocales ne reconstruisent plus toute la page de jeu : la barre vocale se met à jour seule et les indicateurs des maisons ne changent que si les joueurs qui parlent changent. La synchronisation SQL des résultats ne s’exécute plus à chaque message pendant la partie, mais aux étapes nécessaires à l’enregistrement des participants et du résultat.

Lorsqu’un appareil reçoit plusieurs anciens appels d’un coup, seule l’annonce actuelle est lue. Une ancienne annonce automatique en cours est remplacée lorsqu’un nouvel appel arrive ; les séquences privées des cartes gardent leur propre traitement. Cela empêche une file de « réveils » en retard de se décaler progressivement du jeu.

## Bilans de nuit et de vote

Les événements d’élimination portent un identifiant de bilan (`night-N` ou `vote-N`). L’historique complet reste disponible, mais la file des cartes à présenter ne mélange plus un bilan nocturne tardif avec la sentence du vote en cours. Les victimes nocturnes sont retirées de la liste des éliminations courantes au lancement du vote. Les morts en chaîne appartenant à la même résolution gardent leur bilan.

## Pseudo du salon et compte

Le moteur conserve une correspondance `account_names` uniquement dans le snapshot privé du MDJ. Le rendu MDJ affiche `Loup (Kossi)` tout en conservant séparément l’alias réel de jeu. Les joueurs, les maisons qu’ils voient et les messages publics du protocole ne reçoivent pas la correspondance.

En ligne, FastAPI remplace toute déclaration du client par le pseudo du compte réellement authentifié. Un invité sans compte reste affiché avec son seul pseudo de partie. En local sans vérification distante, le pseudo du compte est celui déclaré par l’application du participant ; cette information n’accorde aucun droit ni certification.

## Roue et stabilité

Les huit sentences sont mélangées puis tirées sans remise. Chaque sentence apparaît une fois par cycle et deux cycles ne commencent/finissent pas par le même choix. Une requête invalide n’épuise pas de choix.

Une roue ne peut plus commencer pendant le compte à rebours vers le jour ou la nuit. Le bouton est désactivé et le moteur applique aussi l’interdiction aux requêtes directes. Les erreurs attendues d’un minuteur de transition sont interceptées et remontées au MDJ, au lieu d’arrêter le processus Dart. Une réponse envoyée à un joueur déjà déconnecté ne peut plus interrompre le salon ; les publications tolèrent également la fermeture d’un socket entre deux opérations.

## Résurrection de la Sorcière

Le sauvetage est résolu **au lever du jour**, après les attaques et les autres effets nocturnes. Si la cible reste vivante, elle reçoit seule un événement privé `rescues`. Son application affiche sa carte avec aura jaune, rotation, texte et voix de la Sorcière : « La Sorcière vous a donné une chance. À vous de choisir votre destin. » Le pseudo de la Sorcière n’est transmis que si `reveal_rescuer` est activé. Si une autre attaque tue malgré tout la cible, aucune fausse résurrection n’est annoncée. Le pack Vieille sorcière reste nécessaire à l’extrait sonore ; l’interface propose son téléchargement.

## Entrée dans un salon

Après le premier snapshot validant son entrée, un joueur voit une introduction de 2,8 secondes, passable, intitulée **Partie · Classique**, **Partie · Intense** ou **Partie · Horreur**. Les couleurs, les particules et les textes suivent l’environnement du MDJ :

- Classique : « Les lanternes s’allument. Le village t’attend. »
- Intense : « Sous la neige, chaque regard cache un secret. »
- Horreur : « La brume se referme. Entre… si tu l’oses. »

Le MDJ créant le salon ne voit pas cet écran. Une tentative de connexion refusée ne le déclenche pas. Les mises à jour et reconnexions de la même session ne le rejouent pas ; sortir puis rejoindre un autre salon le réactive. La lecture respecte les mouvements réduits et la mise en arrière-plan. L’introduction utilise les ressources déjà présentes, sans nouveau téléchargement.

## Déploiement et limites des essais

Les changements sont préparés dans le projet local, sans compilation d’APK ni accès au serveur Contabo. Après publication et `git pull`, redémarrer le service avec `sudo systemctl restart legendeofwolf`, puis reconstruire et installer l’application sur les appareils de test. Aucune nouvelle dépendance ou variable d’environnement n’est nécessaire.

Les essais automatisés couvrent les transports, les droits vocaux, les rôles et les salons utilisant réellement Dart derrière FastAPI. Ils ne mesurent pas la latence LiveKit réelle des réseaux Wi-Fi/4G des téléphones : un essai à deux appareils reste nécessaire. Des captures natives des trois entrées sont disponibles sous `apps/mordeviel/build/previews/room-entrance-*.png`.

Validation finale : **82 tests Flutter et 27 tests backend passent**. L’analyse Dart et Ruff sont sans anomalie sur les fichiers concernés. Les captures des entrées Intense et Horreur ont été inspectées avec les polices et le fond réels. Le banc Python Windows signale encore les avertissements de dépréciation TestClient et de fermeture de transports de sous-processus connus ; ces avertissements ne font pas échouer les scénarios.
