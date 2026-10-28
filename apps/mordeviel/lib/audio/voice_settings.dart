import 'package:flutter/material.dart';
import 'classic_audio.dart';
import 'package:local_host/local_host.dart' show mdjNarrationLines;
import '../content/pack_store.dart';
import '../content/downloads_screen.dart';

class VoiceSettings extends StatelessWidget {
  const VoiceSettings({super.key, required this.audio, this.onNarrationChange});
  final ClassicAudio audio;
  final void Function(String profile, bool automatic)? onNarrationChange;
  void select(String id) => onNarrationChange == null
      ? audio.selectVoice(id)
      : onNarrationChange!(id, audio.roomAutomatic);
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
          if (onNarrationChange != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Voix automatique du MDJ'),
              subtitle: const Text(
                'Appels et rendormissements pour tout le salon. Désactive pour les annoncer toi-même.',
              ),
              value: audio.roomAutomatic,
              onChanged: (value) => onNarrationChange!(selected.id, value),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              onNarrationChange == null
                  ? 'Activer les voix OFF'
                  : 'Écouter les voix sur cet appareil',
            ),
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
                select(
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
              if (id != null) select(id);
            },
          ),
          const SizedBox(height: 10),
          Text(selected.description),
          if (!selected.id.startsWith('classic_'))
            ListenableBuilder(
              listenable: PackStore.instance,
              builder: (context, _) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  PackStore.instance.installed(
                        'voice-${selected.id.replaceAll('_', '-')}',
                      )
                      ? Icons.offline_pin
                      : Icons.download,
                ),
                title: Text(
                  PackStore.instance.installed(
                        'voice-${selected.id.replaceAll('_', '-')}',
                      )
                      ? 'Voix disponible hors connexion'
                      : 'Pack vocal à télécharger avant de jouer',
                ),
                trailing: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DownloadsScreen(),
                    ),
                  ),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          if (!mdjNarrationLines.keys.every(
            (cue) => selected.supports('mdj_$cue.wav'),
          )) ...[
            const SizedBox(height: 8),
            Text(
              '${mdjNarrationLines.keys.where((cue) => selected.supports('mdj_$cue.wav')).length}/${mdjNarrationLines.length} annonces disponibles. Les autres annonces restent à lire par le maître du jeu pendant leur préparation.',
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: audio.canPreviewVoice ? audio.previewVoice : null,
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const Text('Écouter cette voix'),
          ),
          Text(
            onNarrationChange != null
                ? 'Le profil choisi par le MDJ s’applique à tous les joueurs du salon.'
                : 'Voix validée. Le choix est conservé et s’applique au prochain appel.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
        ],
      );
    },
  );
}
