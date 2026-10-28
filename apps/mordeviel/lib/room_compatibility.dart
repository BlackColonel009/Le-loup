import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart';

/// Un ancien salon ne doit pas être complété avec des règles inventées côté client.
bool hasRoomConfiguration(Map<String, dynamic> room) {
  final deck = room['deck'];
  const roles = ['villager', 'werewolf', 'seer', 'witch', 'hunter'];
  return deck is Map &&
      deck.keys.every(roleIds.contains) &&
      deck.values.every((n) => n is int && n >= 0 && n <= 20) &&
      roles.every((id) => deck[id] is int && deck[id] >= 0 && deck[id] <= 20) &&
      room['seer_camp_only'] is bool;
}

class IncompatibleRoomNotice extends StatelessWidget {
  const IncompatibleRoomNotice({super.key, this.onLeave});
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Salon à recréer', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      const Text(
        'La configuration des rôles de ce salon est absente ou incompatible. '
        'Redémarre les applications du MDJ et des joueurs, puis crée un nouveau salon. '
        'Un rechargement à chaud ne met pas à jour un salon déjà ouvert.',
      ),
      if (onLeave != null) ...[
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onLeave,
          child: const Text('Quitter ce salon'),
        ),
      ],
    ],
  );
}
