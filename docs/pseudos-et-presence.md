# Pseudos de partie et présence des amis

## Identité dans le salon

À chaque nouvelle entrée ou création de salon en ligne, une fenêtre demande un pseudo de partie de 1 à 24 caractères. Le champ n’est pas prérempli avec le nom du compte. En local, le champ d’entrée est également nommé « Pseudo de partie ».

Le serveur conserve ce choix pour les maisons, les votes, les actions et les discussions du salon. Le pseudo du compte communautaire ne change pas. Les droits, les amitiés et les statistiques restent attachés au compte authentifié, jamais au pseudo saisi. Le moteur refuse les pseudos déjà occupés dans le salon. Une reconnexion technique conserve l’identité de la place ; sortir puis entrer à nouveau permet un nouveau choix avant le lancement d’une partie.

## Présence et alertes

L’application au premier plan envoie un signal toutes les 15 secondes. Les badges du Cercle du village, réservés aux amis acceptés, affichent :

- **Connecté** : au moins un appareil a un signal de premier plan datant de moins de 90 secondes.
- **Absent** : application passée en arrière-plan ; ce statut reste valable cinq minutes sans nouveau signal.
- **Déconnecté depuis…** : déconnexion explicite ou expiration du délai, avec date et heure locales du téléphone. L’heure est estimée par le délai d’expiration si l’application a été fermée brutalement. Si aucune présence n’a encore été reçue, seul « Déconnecté » apparaît.

Les appareils sont agrégés : fermer un appareil ne déconnecte pas le compte si un autre est actif. La déconnexion du compte désactive les présences liées à cette session.

Une nouvelle connexion après un état déconnecté avertit les amis dans l’application et, s’ils ont activé les notifications, sur Android. Les retours de l’état absent et les reconnexions dans les 15 minutes ne produisent pas de répétitions. Les blocages et suppressions d’amis coupent ces alertes. Les accusés de lecture dans l’application et les livraisons téléphone sont indépendants.

Les notifications téléphone réutilisent le suivi périodique Android existant, sans Firebase. La tâche est demandée toutes les 15 minutes, mais Android peut la retarder, notamment en économie d’énergie ou après un arrêt forcé. Le planificateur du backend seul ne peut pas réveiller un téléphone. Les alertes de présence expirent après une heure pour éviter les notifications anciennes.

## Déploiement

Transférer les modifications du backend et du moteur puis redémarrer `legendeofwolf`. Les nouvelles tables sont créées automatiquement au démarrage. Reconstruire l’application pour le choix du pseudo, les badges et les alertes. Aucun nouveau pack de contenu requis.
