# Refonte des voix OFF

État actuel : dix timbres neuronaux intégrés directement à la demande de l’utilisateur.
Les dix appels des loups et dix aperçus sont embarqués, ainsi que l’annonce de
découverte du rôle avec la voix du loup-garou : 21 fichiers au total. Les autres
annonces restent à produire ; leur disponibilité est affichée par profil dans
les réglages et le MDJ les lit en attendant. Aucun repli vers les voix Windows.
Les traitements longs ont été arrêtés à la demande de l’utilisateur, qui fait
lui-même le build. La génération locale reste reprenable. Aucune compilation
installable n’a été lancée.


Les anciennes voix Microsoft Windows sont désactivées (`isApproved: false`) et exclues du pubspec. Une préférence mémorisée ne permet pas de les réactiver. Musique, griffures, hurlement et météo restent disponibles. Le MDJ lit les appels en attendant une narration validée.

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

Les trois références validées ne doivent pas être remplacées. Les auditions
supplémentaires attendent la validation de l’utilisateur. Le moteur de génération
reste sur le PC de développement ; les téléphones ne chargent que les fichiers audio.


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
