# Immersion — lot 1 : caméra et gestes du village

1er novembre 2026 — première livraison du [plan immersion et vocal](plan-immersion-et-vocal.md).

## Problèmes identifiés

- Le glissement vertical pouvait être remporté par la page défilante : l'écran bougeait au lieu du village. Un scénario automatisé a reproduit ce comportement avant correction.
- Le calcul du zoom utilisait le maximum des trois axes d'une matrice dont l'axe Z restait à 1. Une carte réduite était donc mesurée comme ayant un zoom de 100 %, ce qui faussait les boutons et les gestes.
- Une marge fixe de 250 unités ne convenait pas à tous les rapports entre terrain et écran. La caméra possède désormais des limites par axe, calculées à partir des dimensions réellement affichées.
- Une rotation réinitialisait la caméra. Les tests reproduisaient la perte du lieu observé ; la nouvelle caméra conserve ce point et le niveau de zoom relatif à la vue globale, avec ajustement aux bords.

Aucun plantage fatal du téléphone n'a été reproduit. Ces corrections traitent les défauts de navigation constatés ; un éventuel autre crash devra être identifié avec son erreur exacte.

## Changements réalisés

`apps/mordeviel/lib/village/village_camera.dart` centralise le zoom et les limites. Tous les axes de l'échelle sont cohérents avec le calcul d'`InteractiveViewer`. Le terrain reste centré sur les dimensions où il est plus petit que le cadre ; ailleurs, le déplacement s'arrête aux bords. Les boutons utilisent le même contrôleur que le pincement.

`apps/mordeviel/lib/village/village_map.dart` conserve la caméra pendant les mises à jour du salon. Un nouveau terrain ou un nouveau salon initialise sa propre vue. Rotation et boutons interrompent l'ancien mouvement inertiel. Les maisons, noms, fantômes et protections conservent leur transformation commune. Le cadrage initial remplit le cadre ; « Vue d'ensemble » affiche tout le terrain, avec des bandes si son rapport d'image l'exige.

Les contacts tactiles suspendent le défilement de la page jusqu'au retrait du dernier doigt, y compris après annulation d'un contact. Ce comportement est relié à la page réelle dans `apps/mordeviel/lib/lobby_native.dart`. Le cadre utilise aussi la hauteur disponible en paysage au lieu de conserver un minimum de 290 pixels qui pouvait dépasser l'espace visible.

Des frontières de peinture isolent le terrain et l'ambiance Horreur. Leur bénéfice réel en fluidité reste à mesurer sur appareil ; aucune fréquence d'images n'est garantie par les tests de widgets.

Référence de l'API consultée : [InteractiveViewer — documentation Flutter](https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html). Les limites du terrain sont appliquées dans notre contrôleur ; la marge infinie du widget ne permet pas de perdre le village hors du cadre.

## Vérifications réalisées

- Nouveaux tests `village_map_interaction_test.dart` : pincement sans saut depuis la vue globale, premier bouton de zoom progressif, quatre bords accessibles, rotation, maintien de la caméra lors d'une actualisation, sélection d'une maison dans une partie de deux joueurs, absence de sélection pendant un glissement, reprise du défilement hors de la carte et annulation de deux contacts.
- Suites existantes réussies : `intense_map_layout_test.dart`, `village_alignment_test.dart`, `village_navigation_test.dart`, `village_test.dart`, `horror_update_test.dart`. Elles couvrent notamment vingt maisons, leurs ancrages jour/nuit/élimination, le conseil et l'ambiance Horreur.
- Analyse statique des fichiers de production modifiés et du nouveau test : aucune anomalie.

## Essai de Logan

Après son prochain lancement de l'application, tester les trois thèmes : déplacer la carte avec un doigt, pincer, atteindre les quatre coins et toucher une maison après zoom. Alterner portrait/paysage et vérifier que la zone observée reste cohérente. Après relâchement, faire défiler la page depuis une zone hors du cadre de la carte.

Le build APK et l'essai sur téléphone restent à Logan. Ce lot modifie uniquement le client Flutter : aucun pack à republier ni changement de service Contabo n'est nécessaire pour ces corrections. Le vocal et les lots graphiques suivants restent à réaliser.
