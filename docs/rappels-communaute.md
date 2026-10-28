# Rappels de la communauté

Les emails utilisent un cadre doré sur fond bleu nuit, le logo officiel, un bouton vers le site et un pied de page signé « by Logan R.D ». Le HTML utilise des tableaux et styles intégrés pour les messageries ; une version texte est jointe automatiquement. Le contenu administrateur est échappé avant insertion dans le HTML.

Le service FastAPI existant exécute le planificateur toutes les 60 secondes, sans cron ni dépendance supplémentaire. Les paramètres, échéances et livraisons sont conservés dans SQLite. Garder le service sur un seul worker comme la configuration actuelle du moteur Dart.

Par défaut, les rappels sont activés tous les sept jours. Le premier envoi a lieu sept jours après le premier démarrage de cette version, jamais immédiatement au démarrage. Après une interruption, une seule campagne est préparée, sans rattraper toutes les semaines manquées.

Dans le dashboard web : **Les rappels par email**. Dans l’application : dashboard administrateur, contrôles, **Rappels par email**. Modifier l’activation, la fréquence de 1 à 90 jours, l’objet et jusqu’à 30 phrases (une par ligne). Les phrases tournent dans l’ordre, puis recommencent. La date du prochain envoi est affichée. Modifier seulement les textes conserve l’échéance ; changer la fréquence ou réactiver les rappels reprogramme une échéance après le délai choisi. Désactiver annule les envois encore en attente.

Les dix phrases initiales sont définies dans `backend/src/mordeviel_api/community_mail.py`. Chaque membre reçoit un email individuel, sans les adresses des autres. Seuls les comptes vérifiés, non bannis et non désinscrits sont destinataires. Chaque mail comporte une page de désinscription avec confirmation, indépendante de la connexion au compte. Les mails de sécurité restent actifs.

Le SMTP utilise les variables existantes et `SMTP_USE_TLS=true`. `MORDEVIEL_PUBLIC_URL` définit le domaine public dans les mails ; sa valeur par défaut est `https://legendeofwolf.newtechnologiestg.com`.

Les compteurs indiquent les envois acceptés par SMTP et les échecs ; ils ne prouvent pas une arrivée en boîte de réception. Un envoi est réservé avant SMTP pour éviter les doubles envois au redémarrage. En cas d’échec ou d’interruption pendant l’envoi, aucune relance automatique de ce mail incertain : le membre attend la prochaine campagne. Un lot traite au maximum 100 destinataires par passage. Les données de livraison sont purgées après 30 jours au prochain passage actif.

Déploiement : récupérer les modifications puis `sudo systemctl restart mordeviel`. Les tables sont créées automatiquement dans la base existante. Rebuilder l’application pour disposer du nouveau bouton ; le dashboard web sera disponible après le redémarrage. Aucun email réel de test n’a été envoyé pendant le développement.
