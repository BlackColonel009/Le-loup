# Navigation, conseil et ouverture réaliste — 2 novembre 2026

## S’orienter en partie

L’organisation du jeu est conservée. Une barre permanente donne un accès direct à **Village**, **Conseil**, **Chats** et **Actions** (Préparation avant le lancement, MDJ pour l’hôte). Le menu complet reste accessible en haut. La carte secrète dispose d’un accès direct pour son propriétaire.

Un encart explique la prochaine étape : découvrir sa carte, rejoindre la meute, confirmer une cible, voter, attendre son appel ou retrouver le bilan. Les messages signalent aussi les confirmations, la pause et une connexion interrompue. Le choix reste au joueur ; aucun changement de destination n’est imposé par une notification.

Les votes attendus et les actions disponibles reçoivent une bordure et un point lumineux. Les nouveaux messages affichent un compteur ; la lecture du canal efface ce repère. Les nouvelles sollicitations produisent deux pulsations douces, puis restent signalées sans clignoter en boucle. Les mouvements réduits désactivent la pulsation.

Le conseil conserve **Discussion** et **Réunion et vote**. Le bouton « Voter maintenant » ouvre le scrutin, même depuis l’onglet Discussion. Les noms Meute et Privé ne sont affichés qu’aux participants qui reçoivent ces accès, ou au MDJ pour la meute. Un villageois extérieur ou un spectateur ne voit ni contenu ni compteur d’un canal secret. L’échange des amoureux ou des Sœurs cesse d’être proposé à son expiration.

Le chat du conseil reprend des bulles plus lisibles, des initiales liées aux pseudos de partie, une indication Ouvert/Lecture/Pause/Spectateur et une saisie arrondie avec stickers. Les réactions sur les maisons sont conservées pour le conseil et la meute. Les échanges amoureux/Sœurs n’envoient aucune réaction publique sur la carte. Le brouillon public est conservé au passage du débat au vote ; un changement de canal efface le brouillon pour empêcher sa publication dans un autre groupe. Les transitions de hauteur et l’ouverture du clavier conservent le champ et son focus.

## Ouverture locale

L’ouverture est remplacée par une animation Flutter avec **textures photoréalistes générées**, et non une vidéo filmée. Elle fonctionne sans connexion sur Android et Windows, sans ajouter un lecteur vidéo à l’application.

1. L’écran commence en noir et laisse apparaître le tissu noir.
2. Vers 0,38 seconde : première main, trois griffures diagonales et une projection de poussière et de fibres.
3. Vers 1,10 seconde : seconde main dans le sens opposé, trois nouvelles griffures et une seconde projection.
4. Après le second coup, vers 1,67 seconde : le tissu se déchire et les deux pans s’écartent. Les marques restent attachées à chaque pan pendant son déplacement. Les bords centraux sont irréguliers et effilochés.
5. L’ouverture se termine après 3,8 secondes, puis l’accueil reprend son hurlement et sa musique habituels. Le bouton Passer, la pause en arrière-plan et les mouvements réduits restent disponibles.

Les panneaux réagissent aux coups et conservent leurs dégâts ; ils ne sont pas remplacés par des rideaux intacts lors de l’ouverture. Les particules sont calculées localement, sans nouvelle image ni téléchargement pour chaque impact.

### Sons et provenance

Les trois effets viennent d’une **prise de son réelle de tissu déchiré** de Joseph SARDIN : [Cloth / Tissu, son 0013 — BigSoundBank](https://bigsoundbank.com/cloth-s0013.html), publié en **CC0**. Les deux coups sont orientés de gauche à droite ; la déchirure finale est centrée. Compression douce, normalisation et fondus courts adaptent le niveau au jeu ; aucune onde de déchirure synthétique n’est ajoutée.

La source originale est conservée dans `tools/audio/sources/cloth_0013.mp3`. Le script `tools/audio/compose_claws.py --ffmpeg /chemin/vers/ffmpeg` reconstruit les deux griffures et `curtain_tear.wav`. Les volumes, le mode silencieux et la mise en arrière-plan restent pilotés par le système audio existant.

Les textures du rideau et des griffures ont été produites avec l’outil intégré **image_gen.imagegen**, puis copiées dans :

- `apps/mordeviel/assets/branding/opening/black_curtain.png`
- `apps/mordeviel/assets/branding/opening/claw_tears.png` (transparence réelle)

Les **prompts exacts**, les empreintes des fichiers et la provenance/licence du son sont archivés dans `tools/audio/opening_media.json`. Les sources générées initiales sont conservées dans le dossier Codex ; l’application référence seulement les copies du projet.

### Aperçus et vérifications

Un aperçu H.264 avec son, exporté depuis l’animation réelle, se trouve dans `media/opening/mordeviel-opening-preview.mp4` (540 × 960, 30 images/s, 3,8 s). Il sert à la revue ; l’application joue les textures et les effets nativement. Le MP4 n’est pas embarqué dans l’APK.

Les tests ciblés vérifient l’ordre des deux coups et du déchirement, la fin unique, le bouton Passer, les mouvements réduits, la sélection du bon son, la navigation, les votes attendus, les messages non lus, les canaux privés et la conservation du clavier. Des captures des écrans réels Village, Conseil, Vote et Meute sont disponibles sous `apps/mordeviel/build/previews/navigation-*.png`.

Ces changements sont côté application. Aucun APK n’a été compilé et aucun serveur distant n’a été modifié. Les performances sur téléphone physique restent à vérifier lors des essais de Logan.
