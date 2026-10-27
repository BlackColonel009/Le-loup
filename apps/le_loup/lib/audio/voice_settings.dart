import 'package:flutter/material.dart';
import 'classic_audio.dart';

class VoiceSettings extends StatelessWidget {
  const VoiceSettings({super.key, required this.audio});
  final ClassicAudio audio;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: audio,
    builder: (context, _) {
      final selected = audio.voiceProfile;
      final available = audio.availableVoices;
      if (available.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Narration', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Les appels sont lus en direct par le maître du jeu.'),
            const SizedBox(height: 8),
            const Text(
              'Les nouvelles voix expressives seront proposées après validation des essais.',
            ),
            const SizedBox(height: 20),
          ],
        );
      }
      final choices = available.where(
        (profile) => profile.edition == selected.edition,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Voix OFF', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activer les voix OFF'),
            value: audio.narrationEnabled,
            onChanged: (value) => audio.levels(narration: value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('edition-${selected.edition}'),
            initialValue: selected.edition,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ambiance de la voix'),
            items: [
              for (final edition in available.map((p) => p.edition).toSet())
                DropdownMenuItem(value: edition, child: Text(edition)),
            ],
            onChanged: (edition) {
              if (edition != null) {
                audio.selectVoice(
                  available
                      .firstWhere((profile) => profile.edition == edition)
                      .id,
                );
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('voice-${selected.id}'),
            initialValue: selected.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Narrateur ou narratrice',
            ),
            items: [
              for (final profile in choices)
                DropdownMenuItem(value: profile.id, child: Text(profile.label)),
            ],
            onChanged: (id) {
              if (id != null) audio.selectVoice(id);
            },
          ),
          const SizedBox(height: 10),
          Text(selected.description),
          if (!ClassicAudio.voiceAssets.every(selected.supports)) ...[
            const SizedBox(height: 8),
            Text(
              '${ClassicAudio.voiceAssets.where(selected.supports).length}/${ClassicAudio.voiceAssets.length} annonces disponibles. Les autres annonces restent à lire par le maître du jeu pendant leur préparation.',
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: audio.canPreviewVoice ? audio.previewVoice : null,
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const Text('Écouter cette voix'),
          ),
          Text(
            'Voix validée. Le choix est conservé et s’applique au prochain appel.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
        ],
      );
    },
  );
}
