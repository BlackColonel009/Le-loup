# Ancrage des maisons

Les positions sont des points d’appui au sol, en proportions du décor. Le point reste fixe pendant la nuit, l’élimination, une déconnexion ou un changement de zoom. La maison, son nom, sa lueur et son fantôme dérivent de ce même point. L’image du terrain et les maisons utilisent la même transformation de caméra.

Classique : emplacements conservés sur le décor 1376 × 768, maisons ajustées à 112 unités pour limiter le débordement sur les parcelles voisines. Intense : terrain de travail 3072 × 2048, vingt emplacements et maisons de 238 unités. Horreur : même rapport d’image que le fichier 1536 × 1024, quatre rangées recalées à la main sur les parcelles réelles, maisons de 190 unités. Les quatre grandes parcelles occidentales peuvent accueillir une seconde maison pour les places 17 à 20 ; aucune cinquième rangée n’est placée dans les arbres ou la rivière.

Chaque état jour/nuit/éliminé possède des métadonnées de cadrage. Les exports Intense/Horreur ignorent les pixels presque transparents (alpha ≤ 8) pour calculer le cadre visible, sans modifier les PNG. Le bas du cadre et son centre horizontal sont alignés au même point d’appui. Le visuel classique de secours conserve son propre cadrage lorsque le pack Horreur manque.

`tools/sync_eliminated_house.py` conserve ces métadonnées pour les trois thèmes lors des prochaines synchronisations. Les tests de placement utilisent vingt joueurs en portrait et en paysage, avec le vrai pack Horreur installé dans un répertoire temporaire, et vérifient la stabilité jour/nuit/éliminé. Les captures des trois thèmes ont été examinées visuellement.
