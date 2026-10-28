import 'package:flutter/material.dart';
import 'downloads_screen.dart';
import 'pack_store.dart';

Future<bool> prepareRoomContent(
  BuildContext context,
  Map<String, dynamic> room, {
  required bool playsAudio,
}) async {
  final store = PackStore.instance;
  final profile = room['narration_profile'] as String? ?? 'classic_male';
  final required = <String>[
    if (room['visual_pack'] != 'horror' && ((room['card_styles'] as Map?)?.values.contains('horror') ?? false)) 'horror-cards',
    if (room['visual_pack'] == 'horror') ...[
      'horror-cards',
      'horror-village',
      if (playsAudio) 'horror-ambience',
    ],
    if (playsAudio &&
        room['automatic_narration'] != false &&
        !profile.startsWith('classic_'))
      'voice-${profile.replaceAll('_', '-')}',
  ];
  if (required.isEmpty) return true;
  await store.initialize();
  if (required.every(store.installed)) return true;
  try {
    await store.refresh();
  } catch (_) {
    /* Explain offline downloads below. */
  }
  if (!context.mounted) return false;
  if (required.every(store.installed)) return true;
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Préparer les packs du salon'),
      content: const Text(
        'Télécharge les visuels et la voix choisis par le MDJ avant de confirmer. Ils resteront disponibles hors connexion.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Plus tard'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Mes téléchargements'),
        ),
      ],
    ),
  );
  if (open == true && context.mounted) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()));
  }
  return required.every(store.installed);
}
