# Village Intense Premium : terrain v3

## Résultat

L'illustration active est `apps/le_loup/assets/village/intense/map_v3.png`.
L'ancienne `map.png` est conservée comme source historique. La nouvelle image
est une variante créée avec l'outil intégré imagegen à partir de l'ancienne map.
Elle ne contient pas de maisons : elles restent ajoutées par le jeu, une par
joueur connecté, avec leur état jour/nuit/éliminé.

La zone de jeu Intense mesure 3072 × 2048 unités logiques, contre 1376 × 768 pour
le village classique. Vingt emplacements sont répartis en quatre colonnes et
cinq rangées, autour de rues et d'une place centrale. Les coordonnées sont dans
`intenseVillagePlots` de `lib/village/village_map.dart`.

Les maisons Intense sont affichées plus grandes (238 × 238) ; leurs noms disposent
d'une largeur de 260 unités. Leur emprise totale est séparée de celle des maisons
voisines. Les états et les noms restent ancrés au même endroit pendant les phases
jour/nuit. La protection du Salvateur et les fantômes suivent les nouveaux points.
La neige continue d'être affichée quelle que soit la phase.

Le panneau du village prend davantage de hauteur avec ce thème. En portrait,
le cadrage initial garde les deux colonnes centrales accessibles. Le déplacement,
le pincement et les boutons +/− permettent de parcourir le terrain ; « Vue
d'ensemble » affiche le plateau entier. Changer de thème recalcule le cadrage.

## Vérification

`test/intense_map_layout_test.dart` vérifie les vingt emplacements sans
chevauchement, le rendu en 1440 × 1000 et 390 × 844, l'interaction avec les maisons,
le zoom, la stabilité des positions la nuit et le retour à la carte classique.
Pour recréer les captures de contrôle, depuis `apps/le_loup` :

```powershell
flutter test test/intense_map_layout_test.dart --dart-define=CAPTURE_INTENSE_MAP=true
```

Captures dans `build/previews/intense_map_1440.png` et `intense_map_390.png`.
Ces rendus de widgets ne compilent pas l'APK.

Cette modification est visuelle : reconstruire et distribuer l'application aux
joueurs. Aucun changement du moteur Dart ni du backend n'est nécessaire.

## Prompt de l'illustration

Mode : outil intégré imagegen, édition à partir de l'ancienne `map.png`, fond
opaque. Prompt utilisé :

> Edit the supplied winter fantasy village game map into a much more spacious,
> carefully planned playable terrain. Keep the same premium hand-painted medieval
> winter forest art direction, blue-white snow, dark trunks at the distant perimeter
> and a restrained narrow golden ornamental border. Landscape 3:2 aspect ratio.
> Crucial game integration: DO NOT paint any houses, buildings, labels, text, numbers
> or user interface. Remove ALL of the old brown outlined foundations. Instead
> create exactly TWENTY spacious, subtly flattened snow-covered building clearings
> arranged in FOUR columns and FIVE rows. Four clearings per row: two on the left
> half and two on the right half, separated by a wide central north-south village
> avenue. Normalized clearing ground centres approximately at x=0.18,0.36,0.64,0.82
> and y=0.22,0.37,0.52,0.67,0.82. These are open snowy neighborhoods, not conspicuous
> empty brown rectangles. Leave generous free snow ABOVE each clearing for a tall
> separate house sprite, no trunks, walls, obstructions or overhanging branches in
> these twenty building areas. Keep the twenty clearing sizes similar without steep
> shrinking perspective. Five narrow horizontal cobbled streets below the five rows
> connect to the central avenue, coherent isometric-ish overhead 2.5D game view,
> mostly near top-down so all lots are visible. A small atmospheric wooden council
> platform in a small circular plaza at x=0.50,y=0.52, only in the central corridor;
> no overlap into house clearings. Paths must lead to each clearing. Make the
> inhabited area occupy most of the map; forest decoration and ruined walls belong
> only at the far perimeter beyond the building sites. No large rocks or props in
> the clearings. Crisp professional mobile board-game environment, coherent snow
> lighting, refined detail. This is a functional empty game board background onto
> which the application will place exactly one house and name label per player.
> Prioritize correct open space and readable geometry over decorative clutter.
