# Feuilletage du grimoire — 3 novembre 2026

Le défilement latéral du Codex est remplacé par une feuille courbe avec recto et verso. Le bord reste lié à la reliure en paysage. Le papier projette une ombre mobile et change de lumière dans la courbure ; le texte du verso reste lisible et ne s'affiche pas en miroir.

Le joueur tire la page avec le doigt, la relâche pour terminer le mouvement, ou la ramène en arrière. Une petite traction remet la feuille en place. Il peut aussi rattraper une feuille en mouvement. Les flèches, le clavier et le sommaire utilisent le même feuilletage. Le portrait conserve une page ; le paysage montre deux pages et conserve la position de lecture au changement d'orientation.

Le moteur capture les deux pages Flutter une seule fois par mouvement. Une grille déformée anime ensuite leurs textures ; aucune image de parchemin supplémentaire ni dépendance n'est ajoutée. Les textures temporaires sont libérées après le mouvement. Les mouvements réduits changent de page directement, et la mise en arrière-plan suspend le feuilletage.

La pagination continue de mesurer le texte réel, avec la taille de police demandée par le téléphone. Les règles et les informations secrètes affichées dans le Codex restent celles reçues par chaque joueur.

Les tests couvrent la géométrie, les deux faces, les gestes avant/arrière, l'annulation d'un petit mouvement, le portrait, le paysage, les mouvements réduits, le sommaire et la conservation du texte à grande taille.

`media/codex/codex-feuilletage-preview.mp4` est un enregistrement des images réellement rendues par Flutter du mouvement avant puis arrière en paysage. Il n'est pas embarqué dans l'APK.
