# Ressources des éliminations

- **Détonation réelle de fusil de chasse** : Joseph SARDIN, « Shotgun: Shots », enregistrement de ball-trap avec écho extérieur. [Page et licence CC0](https://bigsoundbank.com/shotgun-shots-s0532.html), [fichier source](https://bigsoundbank.com/UPLOAD/mp3/0532.mp3?v=d). Le premier tir est isolé puis répété trois fois à 0 / 0,5544 / 1,1088 s, avec son écho naturel et une normalisation sans saturation. Fichier intégré : `assets/audio/classic/hunter_volley.wav`.
- **Impact de balle** : musdasch, « Bullet Decal », [page et licence CC0](https://opengameart.org/content/bullet-decal), [PNG original](https://opengameart.org/sites/default/files/bullet_hole_0.png). L’image originale est conservée, affichée successivement aux trois points d’impact. Ressource intégrée : `assets/effects/bullet_hole.png`.

Le script `tools/audio/fetch_hunter_media.py` récupère les originaux et prépare ces deux ressources. Il nécessite numpy et soundfile, disponibles dans l’environnement de création audio local. Les sources sont conservées dans `.tmp/hunter-media` pendant la préparation. Le générateur des effets synthétiques ne remplace plus le son du Chasseur.

Les éclairs, éclaboussures et éclats de verre sont des animations originales réalisées dans Flutter : leaders fractals et branches secondaires, cœur blanc et halo bleu, gouttes avec reflets et coulures sur la vitre, et quarante fragments du Maire avec rotation et chute. Les options système de réduction des animations sont respectées. Ces images de synthèse ne sont pas des vidéos filmées d’électricité ou de sang.
