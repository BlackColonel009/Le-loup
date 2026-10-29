import 'package:flutter/material.dart';

String friendPresenceLabel(Map person) {
  final state =
      person['presence'] ?? (person['online'] == true ? 'online' : 'offline');
  if (state == 'online') return 'Connecté';
  if (state == 'away') return 'Absent';
  final stamp = person['disconnected_at'];
  if (stamp is! num || stamp <= 0) return 'Déconnecté';
  final date = DateTime.fromMillisecondsSinceEpoch(
    (stamp * 1000).round(),
  ).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return 'Déconnecté depuis le ${two(date.day)}/${two(date.month)}/${date.year} à ${two(date.hour)}:${two(date.minute)}';
}

class FriendPresenceBadge extends StatelessWidget {
  const FriendPresenceBadge({super.key, required this.person});
  final Map person;
  @override
  Widget build(BuildContext context) {
    final state =
        person['presence'] ?? (person['online'] == true ? 'online' : 'offline');
    final color = switch (state) {
      'online' => const Color(0xFF7BC995),
      'away' => const Color(0xFFE1BA78),
      _ => const Color(0xFFADB0BA),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: .09),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state == 'away' ? Icons.bedtime_outlined : Icons.circle,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                friendPresenceLabel(person),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
