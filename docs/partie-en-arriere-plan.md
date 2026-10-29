# Partie et confirmation en arrière-plan

Le moteur ne confond plus une perte de transport avec un départ volontaire : la place, le pseudo, le jeton de reprise et la confirmation « prêt » sont conservés. En cas de perte de connexion avant distribution, une place est réservée deux minutes. Elle est ensuite retirée si le joueur ne revient pas ; le MDJ peut aussi la retirer lui-même. Après distribution, la place garde son rôle pour une reconnexion.

Le client signale le passage en arrière-plan sans modifier sa confirmation. Un joueur prêt, explicitement en arrière-plan, peut participer à la distribution même si son transport doit être repris. Un joueur déconnecté sans ce signal bloque toujours la distribution. Les changements de composition et de règles par le MDJ continuent à demander une nouvelle confirmation : minimiser l’application ne constitue pas un tel changement.

La reconnexion automatique réutilise le jeton de session, y compris avant la distribution. Elle ne recrée pas un joueur avec une confirmation vide. Les tentatives sont espacées de deux à dix secondes, limitées à douze, et s’arrêtent après une exclusion ou une fermeture de salon. Le retour au premier plan permet aussi de réessayer. Quitter volontairement le salon envoie `room.leave` et libère immédiatement la place avant distribution.

## Android

Le salon confirmé démarre un service de synchronisation de premier plan avec une notification discrète « Partie en cours ». Un verrou CPU partiel maintient les échanges du moteur Flutter pendant le passage à une autre application ; il ne maintient pas l’écran allumé. Le service s’arrête à la sortie du salon, à la fin de partie, lors de la fermeture de la tâche ou à l’échéance imposée par Android. Aucun redémarrage automatique après fermeture et aucune connexion Firebase ne sont ajoutés.

Les services `dataSync` ont une limite Android de six heures en arrière-plan sur les versions concernées : voir [documentation Android](https://developer.android.com/develop/background-work/services/fgs/timeout). Les restrictions constructeur, un arrêt forcé, le mode silencieux et les permissions système restent applicables.

Quand le MDJ distribue les cartes et que l’écran du joueur est en arrière-plan, une notification de lancement demande de revenir dans Mordeviel, avec son et vibration si autorisés. Elle n’est émise qu’une fois et ne contient pas le rôle secret. Toucher la notification ramène à l’activité de jeu existante. Le canal de jeu est distinct des alertes sociales et ne dépend pas d’un compte communautaire pour une partie locale. Désactiver les alertes sociales n’efface pas celles de la partie.

Trade Care a été consulté pour la gestion des canaux sonores, permissions et du suivi des notifications. Son suivi périodique de premier plan ne remplace pas le maintien d’une connexion de jeu en arrière-plan.

L’alerte de début de partie utilise maintenant une création courte : « Le village t’attend… », avec le narrateur grave Intense déjà approuvé, sur un fond musical de suspense original. Le fichier est intégré directement à Android (`res/raw/mordeviel_game_start.wav`) afin de fonctionner sans téléchargement de pack. Le canal `mordeviel_game_start_v2` permet d’appliquer ce son aux installations qui avaient déjà créé l’ancien canal au son standard. La notification permanente de connexion reste silencieuse.

Dans le profil personnel, **Son de début de partie** propose **Mordeviel · Voix et suspense** ou **Son standard du téléphone**. Le choix est enregistré dans le compte et gardé sur l’appareil pour les parties locales sans Internet. Deux canaux Android distincts appliquent le bon son. Une ancienne application qui ne transmet pas ce nouveau réglage ne le réinitialise pas. Les réglages Android de volume, silence et autorisation continuent de s’appliquer.

## Déploiement et validation

Mettre à jour le moteur Dart sur le serveur et redémarrer `legendeofwolf`, puis reconstruire l’APK. Aucun pack de contenu à reconstruire. Les tests automatisés couvrent le statut prêt, la reprise du rôle après lancement, le départ volontaire, l’expiration d’une place et l’absence d’alertes en double. Le comportement du service natif et du son doit être validé sur téléphone après reconstruction ; aucun APK n’est compilé ici.
