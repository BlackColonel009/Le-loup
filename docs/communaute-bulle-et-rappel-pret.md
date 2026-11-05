# Bulle communauté et rappel des joueurs non prêts

Modifications du 4 novembre 2026.

## Discussion de la communauté

Les nouveaux messages de la communauté utilisent la pile d’alertes affichée dans toute l’application, y compris pendant une partie. Une icône Communauté affiche le nombre de messages reçus et un aperçu « pseudo : message ». Après cinq secondes, le texte et sa jauge disparaissent ; l’icône reste accessible. La toucher ouvre la discussion au-dessus de l’écran courant. Un glissement permet de masquer la bulle ; un nouveau message la fait réapparaître.

Les messages de son propre compte et ceux reçus pendant la consultation de la discussion ne créent pas d’alerte. Le premier chargement sert de référence et ne signale pas l’ancien historique. Le suivi est actif au premier plan, avec la même vérification que les messages privés. Cette modification n’ajoute pas de notification téléphone pour la discussion publique.

Vérification du 5 novembre : la lecture ne reste active que lorsque l’onglet Discussion est sélectionné et sa page visible. Passer au Support, aux annonces ou à une autre page rétablit les alertes. Le même contrôle de visibilité est appliqué au chat privé pour reprendre correctement la lecture au retour d’une autre page.

Après le premier chargement, le suivi récupère uniquement les messages plus récents avec le curseur `after`, pour éviter de retélécharger l’historique pendant les parties.

## Rappel depuis la préparation

Le bouton **Lancer et distribuer les rôles** reste utilisable lorsque des joueurs ne sont pas prêts. Chaque tentative envoie un événement privé aux seuls joueurs connectés qui n’ont pas confirmé leur disponibilité. La distribution reste refusée tant que les conditions de lancement ne sont pas réunies.

Le joueur reçoit dans l’application un rappel et, sur Android, une notification **On vous attend !** : « On vous attend pour débuter le jeu. Revenez dans le salon et indiquez que vous êtes prêt. » Chaque nouvelle tentative déclenche un nouveau rappel. La notification utilise le son de message choisi ; la toucher ramène dans l’application. Aucun rôle n’est distribué ou révélé par ce rappel.

Le rappel utilise la connexion du salon, aussi bien en local qu’en ligne. La réception en arrière-plan dépend du maintien de cette connexion et de l’autorisation Android des notifications, comme le lancement de partie existant. Les joueurs déconnectés ne reçoivent pas de rappel différé.

## Vérification et livraison

Tests Flutter des aperçus communauté et des messages privés, analyse statique des fichiers Flutter concernés et test WebSocket local des rappels répétés, du filtrage des joueurs prêts et du lancement après confirmation.

Reconstruire l’application et mettre à jour le moteur Dart du serveur pour les salons en ligne. Un essai sur téléphones reste nécessaire pour confirmer le rendu, le son et la réception en arrière-plan. Aucun APK n’est construit et aucun serveur distant n’est modifié dans cette intervention.

Contrôles du 5 novembre : 35 tests Flutter et 27 tests backend réussis, analyse Dart et Ruff sans erreur. Les tests en ligne utilisent FastAPI et le vrai moteur Dart : refus de lancer tant qu’un joueur n’est pas prêt, réception du rappel sur sa connexion, puis distribution après confirmation. Le scénario WebSocket local valide aussi les rappels répétés et l’absence de rappel aux joueurs déjà prêts. Les tests ne remplacent pas la validation Android des notifications lorsque le téléphone est en veille.
