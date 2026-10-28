# Dernières paroles et fin de partie

## Présentation

Chaque résultat du moteur possède une scène : Village, Loups, Loup Blanc,
Joueur de Flûte, Ange, amoureux ou partie nulle. Elle reprend la carte du thème
actif, un halo et des particules, le titre de victoire et les noms des vainqueurs.
Le bouton de retour ferme la présentation ; la partie reste terminée et les
rôles restent consultables. La présentation ne relance pas automatiquement une partie.
Le contenu défile sur les petits écrans. Le réglage système de réduction des
animations est respecté.

Les scènes d’élimination passent avant la scène finale. Une reconnexion ne
rejoue pas les morts ou une victoire déjà présentes dans le premier instantané.

## Son

Deux signatures originales de quatre secondes, composées sans échantillon tiers
avec `tools/audio/compose_endings.py` :

- `ending_bright.wav` : cloches et arpège majeur, Village et autres conclusions.
- `ending_dark.wav` : basses et harmonie tendue, victoire des Loups.

Le jingle précède l’annonce vocale. Les dernières paroles et annonces attendent
la fin du son précédent. La musique et la météo baissent pendant cette séquence.
Le réglage des effets contrôle le jingle ; celui des voix contrôle les répliques.
Le silence général coupe les deux. Quitter le salon ou passer en arrière-plan
annule la séquence en attente.

En local, seul le MDJ diffuse les sons. En ligne, chaque appareil les diffuse
selon ses réglages. Aucun nouveau service ni appel réseau audio n’est nécessaire.

## Voix déjà approuvées

| Événement | Profil |
| --- | --- |
| Village et partie nulle | Duc |
| Loups et Loup Blanc | Loup-garou |
| Joueur de Flûte | Classique masculin |
| Ange | Fantôme |
| Amoureux | Classique féminin |
| Mort de l’Ancien et malédiction | Vieux sorcier |
| Mort du Chasseur | Intense masculin |
| Mort de la Sorcière | Vieille sorcière |
| Mort du Loup-Garou | Loup-garou |
| Mort de la Voyante | Classique féminin |

Ces répliques de personnages gardent leur interprétation même si un autre
narrateur est choisi pour les appels nocturnes. Les références neuronales
approuvées sont réutilisées, sans voix Windows. Textes et profils sont dans
`tools/audio/neural_profiles.json`. Régénération des seuls ajouts :

```powershell
.tools/audio/qwen_onnx/.venv/Scripts/python.exe tools/audio/local_neural.py cues --events
.tools/audio/qwen_onnx/.venv/Scripts/python.exe tools/audio/sync_neural_assets.py
```

Les fichiers embarqués sont vérifiés par empreinte et format. Le contrôle ASR
local (`check_neural_speech.py --pack --events`) aide à repérer les erreurs de
contenu ; il ne remplace pas l’écoute sur téléphone pour juger l’interprétation.

## Toutes les dernières paroles — 28 octobre 2026

Les 17 rôles disposent maintenant d’une réplique, avec une interprétation
féminine dédiée à la Villageoise. La phrase apparaît sous la carte après son
retournement et sa voix démarre à cette révélation. Les textes et associations
de profils sont définis dans `lib/village/ending_data.dart`.

Une griffure marque les cartes éliminées, y compris au vote et par potion.
Glisser vers le bas ou toucher le bouton fait descendre la carte. La réplique
en cours est coupée ; la carte suivante lance uniquement sa propre voix. Le
bouton devient « Carte suivante » lorsque d’autres morts attendent. La victoire
vient après la dernière carte. Les animations réduites sont respectées.

Le texte utilise uniquement le rôle public, même si le joueur peut voir sa
propre carte secrète. Il disparaît avec celle-ci à la mise en arrière-plan.
La malédiction anonyme conserve sa réplique publique sans identifier un joueur.

## Ancien et confidentialité

La malédiction se déclenche sur le passage de `village_powers_lost` à vrai,
jamais sur le seul nom du rôle. Sa mort par les loups garde donc une dernière
parole normale, sans annoncer de perte de pouvoirs. Sa carte reçoit un éclair
doux à apparition unique sur un fond sombre lorsque la malédiction s’applique.

Seul le rôle **public** d’une mort détermine sa réplique. Un rôle gardé secret
ne reçoit aucune voix permettant de le deviner. Si la perte des pouvoirs est
publique mais l’identité de l’Ancien reste cachée, une scène anonyme annonce la
malédiction sans associer le rôle à un joueur. Aucune règle du moteur ne change.
