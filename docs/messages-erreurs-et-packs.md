# Messages compréhensibles et packs manquants

Un pack absent, incomplet ou à mettre à jour déclenche une fenêtre **Packs à télécharger**, avec les noms des contenus requis et le bouton **Ouvrir les téléchargements**. « Plus tard » annule l’action. La page place les packs demandés en tête, propose leur téléchargement groupé, puis **Revenir au jeu**. Ce parcours ne lance aucun téléchargement sans confirmation. Le catalogue peut être actualisé et les fichiers déjà reçus repris. Le chargement automatique des stickers reçus conserve son comportement antérieur.

Ce contrôle intervient à la préparation du salon, au choix d’un décor ou de cartes mixtes, avant la distribution et la confirmation de disponibilité, pour les commandes du MDJ et lors du choix d’une voix automatique dans le salon. Les stickers utilisent le même parcours. Une image téléchargeable indisponible sans image de secours propose aussi d’ouvrir les téléchargements. Les extraits vocaux et les voix classiques inclus ne nécessitent pas de pack supplémentaire. Un pack déjà installé reste utilisable hors connexion, sans demander un rafraîchissement du catalogue.

Si une phase a changé pendant le téléchargement, l’action du MDJ n’est pas exécutée sur la nouvelle phase : le joueur est invité à consulter l’état courant. Les erreurs audio de pack donnent accès aux téléchargements depuis les paramètres sonores ; elles ne sont pas assimilées à une panne de sortie audio.

Les refus de droits de collection sont distincts des fichiers manquants : télécharger ne déverrouille pas un contenu non acquis, hors accès gratuit ou essai. La création de salon conserve maintenant le message JSON explicatif du backend. Les erreurs de session, de limite de tentatives, de réseau, de connexion sécurisée et d’indisponibilité du service ont des messages propres. Les pages HTML d’erreur du proxy ne sont jamais montrées à l’utilisateur.

Les téléchargements distinguent notamment le manque d’espace, un problème d’enregistrement local, un fichier endommagé, une pause volontaire, un catalogue illisible, un fichier absent du service et une interruption réseau. Aucun diagnostic ne dépend d’un mot de passe ou d’un jeton affiché à l’utilisateur.

Validation : parcours interactif modal → téléchargement ciblé → retour au jeu ; annulation ; pack installé hors connexion ; messages de collection et de proxy ; tests existants d’intégrité/reprise des packs et de narration. Modifications locales : reconstruire l’application et déployer le backend pour obtenir aussi le nouveau texte des restrictions de collection.
