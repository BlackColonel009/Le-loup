# Effets et transitions du 29 octobre

- Horreur au vote : projections étendues à l’écran, gouttes de plusieurs profondeurs, reflets et coulures. Les contrôles restent accessibles, car les effets ne capturent pas les touches.
- Intense et malédiction de l’Ancien : éclairs fractals ramifiés, cœur blanc, halo et extinction progressive, à la place des anciennes lignes simples.
- Chasseur : décalque CC0 original et véritable enregistrement de fusil, trois tirs synchronisés aux impacts. L’animation a été allongée pour garder les trois détonations distinctes. Le cri du loup intervient toujours après la salve, lorsque le rôle est révélé comme loup.
- Maire éliminé : le moteur marque l’événement `was_mayor` ; la carte du mandat se brise en quarante fragments qui tombent. Ensuite seulement, la carte du rôle reçoit ses griffures, sa découpe ou l’effet associé à la cause. La réplique est retardée jusqu’à la révélation du rôle. Les règles de secret du rôle et de succession restent appliquées.
- Les messages privés proposent le même sélecteur de stickers que le conseil, avec le téléchargement du pack si nécessaire. Envoyer un sticker conserve le texte en cours de rédaction ; les mêmes règles d’amitié et d’effacement à 24 h s’appliquent.
- Les commandes des boutons « Commencer la nuit » et « Réveiller le village » programment une transition de cinq secondes dans le moteur. Le changement effectif de phase et la narration arrivent après ces cinq secondes. Le bandeau commun au salon utilise le temps restant du serveur et une horloge monotone locale, sans dépendre du réglage de l’heure du téléphone. Il est affiché au-dessus des onglets et des fenêtres déjà ouvertes. Un second ordre de transition est refusé ; fermer le salon annule le délai.

Les appels directs du moteur restent disponibles pour les simulations automatisées. Les actions des joueurs ne peuvent pas déclencher la commande MDJ `phase.schedule`.

Les nouveaux effets sont dessinés dans l’application. Le petit décalque et les sons sont intégrés à l’APK ; aucun nouveau pack de contenu n’est nécessaire. Les références des médias figurent dans [sources-effets-elimination.md](sources-effets-elimination.md).

Après transfert des modifications sur le serveur, redémarrer `legendeofwolf` pour charger le moteur et la commande actualisés, puis reconstruire l’APK. Aucun APK ni déploiement serveur n’est effectué par cette intervention.
