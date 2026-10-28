# Extension de la collection Classique

Douze nouvelles cartes illustrées, ajoutées aux cinq cartes existantes.
Les PNG finaux sont dans `apps/mordeviel/assets/cards/`. Les images originales
existantes n'ont pas été remplacées.

La galerie « Les cartes du village » montre les 17 cartes. Les nouvelles fiches
disposent du retournement animé, des précisions au verso et du masquage vers le
bas. Les miniatures utilisent un décodage adapté pour limiter leur mémoire.

## État dans le jeu

Les 17 cartes sont jouables dans le salon local. Les pouvoirs et leurs interactions sont décrits dans [les règles des 17 rôles](../gameplay-17-roles.md).

| Identifiant | Carte | Camp de départ |
| --- | --- | --- |
| little_girl | Petite Fille | Village |
| metamorph | Voleur / Métamorphe | Village |
| cupid | Cupidon | Village |
| guardian | Salvateur / Gardien | Village |
| elder | Ancien | Village |
| scapegoat | Bouc émissaire | Village |
| alpha_wolf | Grand Méchant Loup / Alpha | Loups-Garous |
| white_wolf | Loup Blanc / Solitaire | Solitaire |
| wolf_father | Père des Loups | Loups-Garous |
| idiot | Idiot du Village | Village |
| piper | Joueur de Flûte | Solitaire |
| angel | Ange | Solitaire, puis Village si son objectif échoue |

## Choix de fiches

- Métamorphe : échange de deux rôles au début de la partie, conformément à la
  variante déjà retenue pour le projet. Le Voleur avec réserve est une autre règle.
- Alpha : la première mort dans la meute met fin à l'attaque supplémentaire.
- Loup Blanc : attaque personnelle pendant les nuits paires.
- Infection : transformation annoncée discrètement à la nuit suivante, selon
  la variante du projet déjà retenue.
- Ange : objectif au premier vote, puis Simple Villageois s'il survit sans gagner.
- Petite Fille : interception d'un message anonyme avec un risque d'être repérée par la meute. Les interactions sont implémentées dans le moteur local.

L'Idiot appartient au camp Village ; il n'a pas d'objectif solitaire. Ce classement
est aussi celui de la [présentation de Nouvelle Lune par l'éditeur](https://www.asmodee.fr/product/loups-garous-les-nouvelle-lune-ext/).

## Production des images et textes

Images créées avec l'outil intégré `image_gen.imagegen`, une génération par carte,
avec la bordure Classique du dépôt et le style des cartes existantes comme
références. Aucun appel API payant via une clé locale ni pipeline Windows n'a été
utilisé. Les fichiers finaux sont conservés dans le projet.

- `classic_expansion.json` : noms, textes du recto, fiches du verso et sujets.
- `generation-prompts.json` : prompts, références et chemins des rendus sources.
- `tools/cards/build_classic_catalog.py` : génération des données Dart des fiches.

Les PNG sont des cartes complètes, avec textes intégrés à l'image. En cas de
modification d'une règle, mettre à jour la fiche et son recto illustré ensemble.

