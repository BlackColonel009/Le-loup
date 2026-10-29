import 'package:flutter/material.dart';
import 'classic_audio.dart';
import 'voice_settings.dart';
import '../content/downloads_screen.dart';
import '../village/horror_ambience.dart';

void showAudioSettings(
  BuildContext context, {
  void Function(String, bool)? onNarrationChange,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ListenableBuilder(
        listenable: ClassicAudio.instance,
        builder: (context, _) {
          final audio = ClassicAudio.instance;
          Widget volume(
            String label,
            double value,
            ValueChanged<double> change,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label · ${(value * 100).round()} %'),
              Slider(
                value: value,
                label: '${(value * 100).round()} %',
                onChanged: change,
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ambiance sonore',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Musique, effets d’ambiance et narration du maître du jeu.',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Couper tous les sons'),
                value: audio.muted,
                onChanged: (value) => audio.levels(mute: value),
              ),
              VoiceSettings(audio: audio, onNarrationChange: onNarrationChange),
              ListenableBuilder(
                listenable: HorrorPreferences.instance,
                builder: (context, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Frayeurs du thème Horreur'),
                  subtitle: const Text(
                    'Hibou, chauves-souris et sons surprises',
                  ),
                  value: HorrorPreferences.instance.scares,
                  onChanged: HorrorPreferences.instance.setScares,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Mes téléchargements'),
                subtitle: const Text('Voix, stickers et thème Horreur'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DownloadsScreen(),
                  ),
                ),
              ),
              volume(
                'Musique',
                audio.musicLevel,
                (value) => audio.levels(music: value),
              ),
              if (audio.availableVoices.isNotEmpty)
                volume(
                  'Voix du maître du jeu',
                  audio.voiceLevel,
                  (value) => audio.levels(voice: value),
                ),
              volume(
                'Effets sonores',
                audio.effectLevel,
                (value) => audio.levels(effects: value),
              ),
              if (audio.canReplay)
                OutlinedButton.icon(
                  onPressed: audio.muted ? null : audio.replay,
                  icon: const Icon(Icons.replay),
                  label: Text(
                    audio.scene == AudioScene.welcome
                        ? 'Réécouter le hurlement'
                        : 'Répéter le dernier appel',
                  ),
                ),
              if (audio.error != null)
                Text(
                  audio.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (audio.missingPackIds.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DownloadsScreen(
                        requiredPackIds: audio.missingPackIds.toSet(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Télécharger le pack audio'),
                ),
              const SizedBox(height: 12),
              const Text(
                'En local, les sons de la partie sont diffusés uniquement chez le MDJ. Pense à connecter une enceinte.',
              ),
              const ExpansionTile(
                title: Text('Crédits sonores'),
                children: [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Hurlement : Wolf howl, NaturesTemper, Freesound nº 398430, CC0.\n'
                      'Musique : composition originale pour Mordeviel.\n'
                      'Griffures d’ouverture : effets originaux synthétisés pour Mordeviel.\n'
                      'Pluie et grondement : créations originales pour Mordeviel.\n'
                      'Narration neuronale : profils expressifs validés, annonces communes choisies par le maître du jeu.',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  ),
);

class AudioSettingsButton extends StatelessWidget {
  const AudioSettingsButton({super.key, this.onNarrationChange});
  final void Function(String, bool)? onNarrationChange;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Ambiance sonore',
    onPressed: () =>
        showAudioSettings(context, onNarrationChange: onNarrationChange),
    icon: const Icon(Icons.volume_up_outlined),
  );
}
