# Ambiance classique

## Fonctionnement

- À l’entrée dans l’application : ouverture d’environ quatre secondes. Deux
  griffures sont tracées en synchronisation avec deux sons originaux ; deux pans
  d’écran se déchirent et s’écartent pour révéler le logo. Un balayage lumineux
  traverse ensuite le logo de gauche à droite, suivi d’un fondu vers l’accueil.
  Le bouton « Passer » permet de raccourcir la séquence. Elle ne se rejoue pas
  lorsqu’on revient d’un salon ou de la galerie.
- L’initialisation audio s’effectue pendant cet écran. La musique démarre dès
  qu’elle est prête et continue entre l’ouverture et l’accueil, sans reprendre
  au début. Les sons d’ouverture respectent le réglage des effets et le silence
  général.
- À l’accueil, le décor se déplace et zoome doucement sur un cycle aller-retour
  de 56 secondes. Les textes, le logo et les boutons gardent leur position.
  Les animations s’arrêtent en arrière-plan et lorsque la page est masquée.
  Avec les animations réduites, l’ouverture est sobre et le décor reste fixe.
- À la première arrivée sur l’accueil : un hurlement, une seule fois par lancement,
  accompagné d’une musique qui entre progressivement. Revenir de la galerie ou
  d’un salon ne redéclenche pas le hurlement.
- La musique originale dure 64 secondes et boucle : nappes en ré mineur, harpe
  étouffée et mélodie douce. Pas de batterie ni de percussion marquée.
- Les voix françaises suivent les changements de phase publics du serveur.
  Les instantanés, messages et ticks du chronomètre ne répètent pas les appels.
- Pendant une partie locale, seul le MDJ diffuse la musique et les annonces.
  Les joueurs restent silencieux. Aucun nom ou rôle secret n’est ajouté aux voix.
- Un rappel d’enceinte, facultatif et refermable, apparaît au MDJ dans le salon.
- La musique baisse pendant une voix ou le hurlement puis remonte progressivement.
- Réglages séparés : musique, voix et effets, plus silence général. Les volumes
  sont conservés sur l’appareil. Le dernier appel peut être répété manuellement.
- La lecture s’arrête en arrière-plan. Au retour, la musique reprend sans répéter
  l’annonce ni le hurlement. Fermer le salon coupe les sons de la partie.

## Ressources et provenance

Tous les fichiers consommés sont embarqués sous `assets/audio/classic` :
aucun appel à un service de synthèse ni téléchargement pendant une partie.

- `wolf_howl.mp3` : **Wolf howl**, NaturesTemper, Freesound nº 398430.
  Source : https://freesound.org/people/NaturesTemper/sounds/398430/
  Licence indiquée par l’auteur : **Creative Commons Zero (CC0)**.
  Fichier de préécoute haute qualité :
  https://cdn.freesound.org/previews/398/398430_3862281-hq.mp3
- `moonlit_village.wav` : composition originale procédurale pour ce projet,
  reproductible avec `tools/audio/compose_classic.py` et numpy.
- `claw_1.wav` et `claw_2.wav` : deux effets originaux de griffure/déchirure,
  créés avec `tools/audio/compose_claws.py` et numpy, sans ressource tierce.
- `rain_loop.wav` et `thunder.wav` : pluie et grondement originaux synthétisés
  avec `tools/audio/compose_weather.py`. Voir `meteo-village.md` pour leur
  synchronisation et les règles d’affichage.
- Narration : nouvelles voix neuronales Qwen3-TTS, références originales et
  fichiers embarqués sous `assets/audio/classic/neural/`. Les anciennes voix
  Windows sont rejetées et exclues de l’application. Voir `voix-parametrables.md`
  pour la provenance, la production locale et la couverture des annonces.

## Choix de voix

Le réglage **Voix OFF** propose les nouveaux profils neuronaux, dont deux en
Classique, avec mémorisation et extrait d’écoute. L’utilisateur a demandé
l’intégration directe des sept nouveaux profils, sans nouvelle validation
d’écoute. Le passage au multijoueur en ligne reste soumis à ses essais du jeu.

## Interface

Titres : Cormorant Garamond, source Google Fonts, SIL Open Font License 1.1.
Police et licence livrées dans `assets/fonts`.
Source : https://github.com/google/fonts/tree/main/ofl/cormorantgaramond

Textes de lecture : Source Sans 3, même licence OFL, avec sa licence livrée sous
`assets/fonts/SOURCE_SANS_OFL.txt`.
Source : https://github.com/google/fonts/tree/main/ofl/sourcesans3

Logo fourni : copie de `le_loup/logo/logo.png` dans `assets/branding/logo.png`,
affichée avec sa transparence à l’accueil. L’original reste intact.

Les écrans se rapprochent de la planche artistique : taverne plus lumineuse,
titres à empattements, carte agrandie en fonction de l’écran, panneaux sobres
et sélection du conseil encadrée d’or. La planche reste une référence, pas une
texture d’écran appliquée à la place des vrais composants interactifs.
