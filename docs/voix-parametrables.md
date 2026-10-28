# Refonte des voix OFF

Les dix timbres neuronaux approuvés disposent chacun des 28 annonces du MDJ :
découverte du rôle, endormissement, appels, rendormissements, journée et vote.
Les 280 WAV sont embarqués, en plus des aperçus et des répliques de personnages.
La source des textes est `tools/audio/narration_lines.json`, synchronisée avec
le moteur par `tools/audio/sync_narration.py`. Liste complète : `textes-voix-off.md`.
Le build installable reste à la charge de l’utilisateur.


Les voix Microsoft Windows sont exclues du catalogue et du pubspec. Une ancienne
préférence ne les réactive pas. Musique, griffures, hurlement et météo gardent
leurs réglages indépendants.

Une voix neuronale naturelle est acceptée par l’utilisateur. `isApproved` désigne la validation artistique, pas une origine humaine.

## Nouveaux essais

Moteur : Qwen3-TTS-12Hz-1.7B-VoiceDesign.
Démo officielle : https://huggingface.co/spaces/Qwen/Qwen3-TTS
Documentation : https://github.com/QwenLM/Qwen3-TTS

`tools/audio/audition_neural.py` contient dix directions distinctes : classique homme/femme, intense homme/femme, duc, vieux sorcier, vieille sorcière, loup-garou, fantôme, tueur de sang-froid. Aucune voix de comédien copiée ou clonée ; aucun moteur Windows ni API payante dans ce script.

Trois WAV ont été générés dans `docs/audio-auditions` : loup-garou, fantôme et vieux sorcier. Les JSON voisins conservent texte, direction et provenance. Les tentatives suivantes (vieille sorcière, classique masculin) ont échoué avec un événement Gradio `error` contenant `null`. Cause inconnue. Les sept autres profils restent à produire.

Ces extraits ne sont pas encore intégrés au jeu. L’utilisateur doit juger le naturel, le caractère et la prononciation. Le contrôle technique ne remplace pas l’écoute artistique. Après validation : produire toutes les annonces avec une identité cohérente, vérifier contenu et licence de distribution, puis embarquer les fichiers pour la lecture hors ligne.

## Pipeline historique

`render_voice_profiles.ps1` et `build_voice_profiles.py` correspondent à SAPI, rejeté. Ne pas les relancer pour cette refonte. Ils ne doivent jamais approuver automatiquement les anciennes voix.

Le multijoueur en ligne attend toujours la validation locale.

## Validation du 26 octobre 2026

L’utilisateur a approuvé les trois extraits : loup-garou, fantôme, vieux sorcier.
Ils sont maintenant sélectionnables dans les réglages du jeu, sous Horreur.
Les WAV approuvés sont embarqués sous `assets/audio/classic/neural/` et se lisent
hors ligne. Chaque original contient l’appel des loups : le même enregistrement
validé sert pour cet appel et son aperçu. Aucun découpage ni changement de timbre.

La couverture est explicitement limitée à `preview.wav` et `wolves.wav`.
Les phases manquantes restent silencieuses et le MDJ les lit ; le bouton de
répétition y est désactivé. Aucun repli vers SAPI. Les sept autres voix restent
masquées. Le texte de l’appel utilisé est consigné dans chaque manifest.json.

`build_approved_neural.py` utilise le WAV original approuvé comme référence du
modèle Base, pour conserver son identité dans les annonces suivantes. Il est
reprenable et contrôle les WAV avant installation. La première requête de cette
session a échoué avec `error: null` ; aucun nouvel appel n’a donc été fabriqué.
Une nouvelle tentative VoiceDesign Classique a échoué de la même façon.
Il ne s’agit pas d’un refus d’approbation local : le service distant échoue.
La cause exacte (quota ou indisponibilité) n’est pas connue.

Les scripts acceptent un HF_TOKEN optionnel de l’environnement pour un accès
Hugging Face authentifié. Ils ne l’affichent pas et ne font aucun achat.
Après production, étendre les `availableCues` et les assets déclarés au pubspec
uniquement pour les fichiers effectivement disponibles, puis tester.

## Recherche pour les sept profils restants

Les directions originales des sept profils sont prêtes dans `audition_neural.py`.
Autres catalogues officiels examinés pour comparaison, pas des voix intégrées
ni validées en français :

- Narration française masculine/féminine : https://elevenlabs.io/fr/text-to-speech/french
- Voix graves homme/femme, duc et tueur : https://elevenlabs.io/voice-library/villain
- Vieille sorcière (The Ancient Crone) : https://elevenlabs.io/voice-library/witch
- Recherche des voix françaises par langue, âge, genre et personnages : https://elevenlabs.io/docs/fr/eleven-creative/voices/voice-library

Les exemples anglophones de personnages ne prouvent pas leur qualité en français.
Aucun abonnement, compte ni achat ElevenLabs n’a été engagé.

## Production locale sans compte

Le PC de développement possède une RTX 2050 4 Go et 32 Go de RAM. Un environnement
isolé est préparé sous `.tools/audio/qwen_onnx/.venv`. Le moteur ONNX CPU INT4
utilise quatre threads, sans installer PyTorch ni modifier Flutter. Les modèles,
révisions, licences et empreintes sont conservés dans le dossier ignoré `.tools`.

Installation des dépendances : `requirements-local-neural.txt`.
Téléchargement contrôlé : `setup_local_neural.py design`, puis `base`.
Les fichiers sont vérifiés par taille et SHA-256 quand disponible ; les téléchargements
partiels peuvent être repris. Les composants identiques sont réutilisés localement.
Le tokenizer est chargé en mode hors ligne et sans code distant.

Avec le Python de cet environnement :

- `tools/audio/local_neural.py auditions` prépare les sept propositions manquantes.
- `tools/audio/local_neural.py cues` complète les annonces des trois voix approuvées.
- `tools/audio/sync_neural_assets.py` vérifie les références et les empreintes, puis
  déclare uniquement les WAV disponibles dans Flutter et son catalogue.

Les dix références validées ne doivent pas être remplacées. Le moteur de génération
reste sur le PC de développement ; les téléphones ne chargent que les fichiers audio.

## Narrateur commun du salon

Le MDJ choisit le profil avant la distribution, dans la préparation ou les
paramètres sonores. `narration.configure` transmet uniquement l’identifiant du
profil et le mode automatique, validés par le moteur. Les joueurs ne peuvent
pas modifier ces réglages de salon. Les choix personnels de narrateur sont
temporairement remplacés par celui du MDJ, puis retrouvés après le départ.
Le choix du MDJ et sa préférence automatique sont mémorisés sur son appareil.

En local, l’appareil du MDJ diffuse les annonces, idéalement sur une enceinte.
En ligne, chaque appareil diffuse le même profil, selon ses volumes et son
silence personnel. « Voix automatique du MDJ » peut être désactivé pour lire
soi-même les consignes. Ce réglage partagé ne coupe pas la musique, les effets
ni les répliques des personnages.

Chaque changement de phase produit un événement public avec une révision,
un nom de fichier et son texte, jamais une identité ou une cible. La fermeture
d’un appel nocturne annonce le rendormissement du rôle appelé. Les annonces
sont ordonnées et non répétées aux ticks du chronomètre. Réactiver l’automatique
ne rejoue pas les appels passés. Une reconnexion reprend seulement le dernier
appel disponible. L’espionnage de la Petite Fille garde sa discrétion, sans
appel public spécifique.

La génération optionnelle utilise `local_neural.py cues --narration --device cuda
--batch-size 8` sur le poste de développement. Les prédictions résiduelles sont
regroupées ; chaque réplique conserve sa propre référence, son cache, son
échantillonnage et sa fin de séquence. Aucun collage de syllabes ou effet de
transformation de voix n’est utilisé. Les générations existantes sont préservées.


## Réplique de potion

Réplique originale ajoutée : « Alors mon mignon… un petit remontant, ou un aller
simple au cimetière ? Héhéhé ! ». Voix : vieille sorcière neuronale déjà intégrée,
avec sa référence originale. Fichier : `neural/old_witch/witch_potion.wav`.

Déclenchement après confirmation d’une potion de vie ou de mort (une seule
réplique si les deux sont utilisées ensemble). Refuser les potions ne la
joue pas. Le signal `potion_used` est réservé au snapshot du MDJ, jamais envoyé
aux joueurs. Lecture locale uniquement chez le MDJ, volume de voix et silence
respectés, sans répétition lors des mises à jour du salon. Le choix global du
narrateur ne change pas la voix de cette réplique. Aucun changement de règles.
