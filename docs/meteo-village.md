# Météo d’ambiance du village

Le moteur du MDJ choisit une météo une seule fois au début de chaque nuit :
55 % de nuits claires, 27 % pluvieuses et 18 % orageuses avec pluie. Le choix,
la graine graphique et le temps écoulé sont publics et transmis dans les mêmes
instantanés que le reste du village. Ils ne dépendent jamais des rôles,
des victimes, des votes ou d’autres informations secrètes.

La météo ne change aucune règle et ne consomme aucun pouvoir. Les anciens salons
sans champ `weather` s’affichent comme des nuits claires.

## Carte

- Pluie légère ou plus dense sous l’orage, dessinée dans une couche indépendante
  qui laisse les maisons et les bulles cliquables.
- Éclairs doux, uniques et espacés, calculés à partir de la graine et du temps
  public de la nuit. Pas de clignotement rapide.
- Au jour suivant une nuit pluvieuse ou orageuse, la pluie cesse et une lueur
  d’arc-en-ciel pastel accompagne une lumière plus chaude. La lueur reste durant
  cette journée et disparaît à la nuit suivante. Pas d’arc-en-ciel après une
  nuit claire.
- En mode animations réduites, météo statique et absence d’éclairs. Les tickers
  s’arrêtent quand la carte est masquée ou l’application passe en arrière-plan.

## Sons

La pluie en boucle et le grondement occupent deux lecteurs distincts des voix et
de la musique. En local, seul le MDJ les diffuse. Ils respectent le volume des
effets et le silence général. La pluie baisse pendant une annonce ; un nouveau
grondement ne démarre pas pendant la voix du MDJ ou une pause du jeu.

La timeline partagée place le grondement un peu après l’éclair. Un événement déjà
joué n’est pas répété lors des mises à jour réseau. Les événements trop anciens
ne sont pas rejoués à la reconnexion. Fermer le salon ou passer en arrière-plan
coupe ces sons.

`rain_loop.wav` et `thunder.wav` sont deux créations procédurales originales,
reproductibles avec `tools/audio/compose_weather.py` et numpy.

## Nouveau visuel de maison éliminée

Le fichier source attendu est `le_loup/Map/home_rip.png`. Après son remplacement,
`tools/sync_eliminated_house.py` vérifie le fichier et le copie sans retouche dans
`apps/le_loup/assets/village/house_eliminated.png`. Le script ne touche pas au
visuel source. L’affichage utilise désormais les proportions natives et accepte
une taille différente de l’ancien PNG. Le script régénère également
`house_sprite_geometry.dart` à partir des marges transparentes des trois maisons,
pour conserver une taille apparente et un ancrage cohérents, sans modifier les
pixels. Un redémarrage complet recharge l’image.
