import 'package:flutter/material.dart';
import 'require_packs.dart';

Future<bool> prepareRoomContent(
  BuildContext context,
  Map<String, dynamic> room, {
  required bool playsAudio,
}) async {
  final profile = room['narration_profile'] as String? ?? 'classic_male';
  final required = <String>[
    if (room['visual_pack'] != 'horror' &&
        ((room['card_styles'] as Map?)?.values.contains('horror') ?? false))
      'horror-cards',
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
  return ensurePacksAvailable(
    context,
    required,
    reason:
        'Le décor, les cartes ou la voix choisis par le MDJ nécessitent ces packs avant de poursuivre.',
  );
}
