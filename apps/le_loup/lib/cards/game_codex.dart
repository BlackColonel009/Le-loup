import 'package:flutter/material.dart';
import 'classic_role.dart';
import '../room_compatibility.dart';

Future<void> showGameCodex(
  BuildContext context,
  Map<String, dynamic> room,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Codex de la partie'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: !hasRoomConfiguration(room)
            ? const IncompatibleRoomNotice()
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ambiance Classique · Les attributions restent secrètes.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    room['seer_camp_only'] == true
                        ? 'Variante : la Voyante découvre le camp uniquement.'
                        : 'Règles classiques : la Voyante découvre le rôle exact.',
                  ),
                  for (final role in classicRoles)
                    if (((room['deck'] as Map)[role.id] as int? ?? 0) > 0)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          '${role.name} × ${(room['deck'] as Map)[role.id]}',
                        ),
                        subtitle: Text('Camp : ${role.camp} · ${role.phase}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(() {
                              final configured = configuredRole(
                                role.id,
                                seerCampOnly: room['seer_camp_only'] == true,
                              );
                              return '${configured.summary}\n\n${configured.details}';
                            }()),
                          ),
                        ],
                      ),
                  const Divider(),
                  const Text(
                    'Les tirs et réactions sont résolus avant de vérifier la victoire. '
                    'Le Village gagne si aucun loup ne survit. Les loups gagnent s’ils sont '
                    'aussi nombreux ou plus nombreux que les autres survivants. '
                    'Aucun survivant : partie nulle.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cette version s’arrête à la distribution : les actions nocturnes et les votes arrivent ensuite.',
                  ),
                ],
              ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
    ],
  ),
);
