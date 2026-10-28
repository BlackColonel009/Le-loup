# Salons, amis, invitations et profils

Périmètre demandé par Logan : accueil en ligne avec salons publics et thèmes ; mode Mixte conservant les rôles ; joueurs récents ; demandes d’amitié ; invitations avec badges, email et notification téléphone ; historique des invitations fermées ; statistiques du profil, publiques ou réservées aux amis.

Les statistiques proviennent exclusivement du moteur distant, après une partie terminée, et sont comptées une seule fois par partie. Elles ne sont pas importées depuis un téléphone. Les victimes de la meute sont des éliminations collectives confirmées, créditées aux loups ayant participé à la chasse ; les attaques personnelles de loup sont comptées pour leur auteur. Les parties locales anonymes ne produisent pas de classement vérifiable.

Les comptes communauté vérifiés identifient les participants en ligne. Les salons privés restent accessibles par code ; les salons publics exposent seulement leur présentation, leur thème et leur disponibilité, jamais les rôles secrets ou les tokens.

Choix explicite : aucune utilisation de Firebase. Le scheduler FastAPI prépare les notifications et envoie les emails. L’application les récupère lorsqu’elle est ouverte ; Android peut aussi les récupérer avec WorkManager, au mieux toutes les quinze minutes et selon les restrictions d’arrière-plan du système. Ce mécanisme ne garantit pas de push instantané lorsque l’application est fermée ou arrêtée de force. Les préférences et la permission système sont respectées.

L’état des invitations est vérifié côté serveur. Fermeture, fin, démarrage de partie ou expiration désactivent l’accès et la surbrillance, tout en conservant la trace dans l’historique. Blocage, limites d’envoi et désinscription aux emails sont inclus.

Après validation de cette version : conception avec Logan de variantes de gameplay Intense/Horreur, puis achats, cadeaux et droits de collection. Aucun achat réel n’est activé ici.

## Fonctionnement livré

- Salons publics filtrables par thème ; accès privé par code ; seul un compte communauté vérifié peut publier un salon public. Les salons commencés restent visibles avec un accès désactivé.
- Mode Mixte : le MDJ choisit l’apparence de chaque rôle actif avant la partie. Les mécaniques restent identiques ; les cartes secrètes ne sont pas identifiables par leur dos. Les droits de collection et achats viendront ensuite.
- Carnet social : amis, demandes entrantes/sortantes, joueurs récents, profils visitables, blocage et historique des invitations. Les rencontres incluent le MDJ lorsque la partie démarre.
- Une invitation active garde son badge même après consultation. Rejoindre, décliner, fermer le salon, démarrer ou dépasser deux heures désactive cette invitation. Un code réutilisé ne réactive jamais une ancienne invitation.
- Les statistiques ne comptent que les parties en ligne terminées et identifiées. Les victoires suivent les gagnants calculés par le moteur, y compris les joueurs morts appartenant au camp vainqueur. Les tirs du Chasseur et les potions ne sont pas comptés comme des victimes de loups. Un match n’est enregistré qu’une seule fois.
- Un compte ne peut pas occuper plusieurs places dans le même salon ni reprendre la place authentifiée d’un autre compte. Le pseudo vérifié remplace le pseudo envoyé par le client.

## Scheduler et notifications sans Firebase

Le scheduler est lancé automatiquement avec FastAPI : aucun nouveau cron ni service séparé n’est nécessaire. Il vérifie toutes les 30 secondes les invitations expirées et les emails en attente. Les emails sont limités par destinataire et par paire d’amis, respectent le choix du profil et utilisent la configuration SMTP existante. Aucun email réel n’a été envoyé pendant les tests.

Les badges sont rafraîchis toutes les 15 secondes dans l’application active. Android utilise WorkManager avec une fréquence minimale de 15 minutes et une connexion réseau requise. Android peut retarder les tâches, notamment en économie d’énergie ; un arrêt forcé peut empêcher leur exécution jusqu’à la réouverture. Ce dispositif ne promet donc pas une alerte immédiate application fermée. Référence : [documentation Android WorkManager](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work).

La connexion des joueurs dure désormais 14 jours fixes ; celle des administrateurs reste limitée à 24 heures. Un jeton distinct de 30 jours, stocké de façon sécurisée sur le téléphone et uniquement sous forme d’empreinte côté serveur, autorise seulement la lecture et l’accusé de réception des alertes de cette installation. Il ne permet ni de lire le profil ni d’effectuer des actions sur le compte. Déconnexion, changement de mot de passe ou suppression du compte le révoquent. L’enregistrement est renouvelé lorsque l’utilisateur revient connecté. L’arrière-plan Android est optionnel ; les autres plateformes conservent les invitations et badges dans l’application.

Les emails d’invitation possèdent leur propre désinscription, indépendante du rappel hebdomadaire. Les traces d’invitations et notifications sont nettoyées après 90 jours. Les invitations actives sont fermées au redémarrage puisque les salons ne sont pas restaurés.

## Backend et déploiement

Les routes sont regroupées sous `/social` : salons, profils, préférences, amis, rencontres récentes, invitations et notifications. Les routes `/social/device/…` sont exclusivement destinées au jeton limité d’arrière-plan. Les tables SQLite sont créées automatiquement au démarrage dans la base communauté existante. Préserver cette base et ses sauvegardes lors du déploiement.

Après publication des sources et mise à jour du serveur : installer les dépendances backend habituelles, exécuter `dart pub get` dans `packages/local_host`, puis redémarrer le service FastAPI existant. Aucun port supplémentaire ni configuration Firebase n’est requis. Le domaine HTTPS et le proxy WebSocket restent ceux déjà configurés. Les dépendances Flutter ajoutées nécessitent `flutter pub get` avant ton prochain build Android.

Validation : tests backend, moteur distant réel, confidentialité, invitations, blocages, statistiques idempotentes et jetons limités ; tests d’interaction des écrans sur formats portrait/paysage ; analyse statique Flutter. La réception Android en arrière-plan et l’envoi SMTP réel restent à vérifier sur tes appareils et ton serveur. Aucun APK n’a été compilé.
