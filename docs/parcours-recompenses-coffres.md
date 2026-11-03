# Parcours des cadeaux de défis

Mise à jour du 3 novembre 2026 — modifications locales.

## Coffres et lumières

- Classique : stickers et portraits classiques ; bois, cerclages dorés, lumière dorée.
- Épique : bordures illustrées fixes (`effect: artwork`) ; violet, améthyste, plaques et volutes métalliques, lumière violette, sceau alchimique fixe.
- Premium : bordures animées ; bleu nuit, or, gemme cyan, couronne et volutes, lumière cyan avec ornements dorés, sceau alchimique tournant.
- Le sceau comprend des anneaux concentriques, des graduations, des triangles entrelacés et des symboles dessinés.
- Pour plusieurs cadeaux récupérés ensemble, le coffre correspond à la catégorie la plus élevée du lot. Le contenu n’est pas aléatoire.
- Les préférences système de réduction des animations suppriment les secousses et la rotation.

## Parcours

1. Le serveur valide le défi et conserve le cadeau en attente.
2. Le joueur voit la proposition de récupération à la fin de partie ou depuis son carnet.
3. « Plus tard » ferme la présentation sans réclamer le cadeau.
4. « Réclamer » lance la demande au serveur ; les doubles clics et la fermeture pendant la demande sont bloqués.
5. En cas d’erreur, le joueur peut réessayer. La récupération serveur est idempotente : un nouvel essai ne crée pas un second déblocage.
6. Après confirmation, les compteurs sont mis à jour et le coffre commence son ouverture. La liste des cadeaux est temporairement masquée durant cette découverte.
7. L’ouverture terminée, les cadeaux et le message final apparaissent. « Passer l’animation » permet d’atteindre immédiatement cet état sans refaire de demande au serveur.
8. « Super, continuer ! » ferme la présentation. Le carnet propose « Mes portraits et bordures » pour accéder à la personnalisation. Les stickers se trouvent dans les discussions.
9. Un portrait au choix nécessite encore le choix explicite proposé sur le défi récupéré ; ne pas le présenter comme un portrait déjà sélectionné.

La liste visible avant la récupération constitue un aperçu des récompenses connues. Les cosmétiques sont attribués par le serveur, indépendamment de la lecture complète de l’animation.

## Aperçu et vérifications

L’aperçu autonome se trouve dans `design/coffre-recompenses.html`. Il illustre les trois variantes sans réclamer de récompenses réelles.

Vérifications : analyse Flutter des fichiers modifiés, 17 tests Flutter ciblés (défis, récupération, catégorie du coffre), 15 tests serveur des défis. Les tests couvrent notamment les petits écrans, le report, la panne, la récupération et les catégories de coffres.
