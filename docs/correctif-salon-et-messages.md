# Salon du MJ et alertes de messages privés

## Écran blanc à l’arrivée d’un joueur

La vue privée du MJ ajoute le pseudo du compte au surnom de partie. Lorsque `account_names` devient non vide, l’ancienne reconstruction des joueurs produisait des dictionnaires `Map<dynamic, dynamic>`. La carte et les autres vues attendent des `Map<String, dynamic>` : le premier joueur authentifié pouvait déclencher une erreur de rendu.

`hostDisplayRoom` reconstruit maintenant explicitement une liste de dictionnaires typés. Le test de régression fait apparaître successivement trois joueurs avec leurs noms de compte, vérifie que le village reste visible et conserve les surnoms originaux dans l’état du jeu. Le correctif couvre le même chemin d’affichage privé utilisé en ligne et en local.

## Alertes visibles dans toute l’application

La réception est attachée à la racine de l’application. Elle continue donc pendant une partie et ne dépend plus de l’ouverture d’une discussion privée.

- Vérification des messages non lus environ toutes les trois secondes au premier plan, avec une seule requête à la fois.
- Portrait équipé et bordure du correspondant à gauche, badge de non-lus et aperçu du message.
- L’aperçu disparaît après cinq secondes avec sa jauge ; le portrait reste disponible.
- Plusieurs correspondants forment une pile dépliable. La liste dépliée affiche les pseudos.
- Un glissement vers la gauche masque un correspondant pour les messages déjà reçus. Un nouveau message le fait réapparaître.
- Un clic ouvre la conversation au-dessus de la partie. Revenir conserve le salon.
- La lecture retire seulement les messages effectivement affichés ; un message reçu entre-temps reste non lu. Les autres correspondants restent visibles.
- Les stickers utilisent un aperçu texte « Sticker reçu » ; le sticker complet reste disponible dans la discussion.

Les mouvements de la pile ne reconstruisent pas la page de jeu ni ses champs de saisie.

La file des mises à jour de présence ne conserve plus de future déjà terminée : elle est recréée uniquement quand une écriture est nécessaire. Le changement du son de notification synchronise directement le récepteur Android, sans attendre un rafraîchissement complet du cercle social.

## API et confidentialité

`GET /social/chats/inbox` regroupe les non-lus par ami avec son portrait. `POST /social/chats/{id}/read` confirme la lecture jusqu’à un identifiant de message précis. La table `friend_chat_reads` est créée automatiquement au démarrage et supprimée pour les deux côtés lors d’une suppression de compte.

Les messages créent des notifications `message` dans le système social existant. La remise au téléphone est distincte de la lecture. Un clic de notification utilise `chat:<identifiant_ami>` pour ouvrir la bonne discussion. Les notifications deviennent invalides après lecture, blocage, retrait de l’amitié, bannissement ou expiration de la conversation de 24 heures.

Le jeton d’appareil en arrière-plan ne donne pas accès au contenu des conversations : il peut uniquement obtenir les notifications autorisées et confirmer leur remise. Aucun nouvel envoi d’email n’est ajouté.

## Android en arrière-plan

Activer **Profil → Notifications sur mon téléphone**, puis autoriser les notifications Android. Un service de type `remoteMessaging` maintient la réception pendant que l’application est minimisée. Android affiche la notification persistante « Mordeviel · Messages actifs ». La vérification s’effectue environ toutes les six secondes lorsqu’Android laisse le service fonctionner. Au premier plan, la pile d’avatars assure l’alerte et le service ne double pas les notifications de message.

Les identifiants de connexion restent en mémoire dans le service, sans écriture d’un nouveau fichier de secrets. La déconnexion et la désactivation des notifications arrêtent le service. WorkManager conserve sa vérification de secours périodique. Le service est arrêté si l’utilisateur retire complètement la tâche ; les politiques de batterie, la veille et l’arrêt forcé Android peuvent retarder ou empêcher la réception. Il ne s’agit pas d’une garantie de push instantané lorsque l’application est arrêtée.

Références Android : [types de services](https://developer.android.com/develop/background-work/services/fgs/service-types), [travail périodique](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work), [canaux sonores](https://developer.android.com/develop/ui/compose/notifications/channels).

## Sonnerie

Son original de 1,8 seconde : deux petites gouttes avec des réflexions de grotte. Il est généré par `tools/audio/create_message_drop.py`, sans extrait extérieur. Il est inclus en WAV dans les ressources audio et Android. Dans l’application il respecte le silence et le volume des effets ; sur le téléphone le choix enregistré « Son Mordeviel / Son du téléphone » sélectionne le canal adapté. Les réglages sonores Android restent prioritaires.

## Publication et contrôles

Publier le backend modifié, puis redémarrer `legendeofwolf` : les nouvelles tables et l’index sont créés automatiquement. Aucun nouveau paquet Python ni pack de contenu distant n’est nécessaire. Reconstruire ensuite l’application pour inclure la nouvelle interface, le service Android et sa sonnerie.

Les contrôles couvrent le rendu du village à l’arrivée de joueurs, la pile de messages sur petit écran, son expiration, son dépliage, la lecture, le retour à la partie, le glissement, l’arrivée d’un nouveau message et l’ouverture depuis un payload de notification. Les tests serveur couvrent les non-lus, la lecture partielle, la remise sur téléphone, le blocage et l’expiration. Les trois fichiers Kotlin sont vérifiés avec le compilateur local et Android 36, sans construire d’APK.

Un essai sur deux téléphones reste nécessaire pour vérifier la réception et le son réels avec les réglages Android de chacun.
