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
                    room['reveal_roles_on_death'] == true
                        ? 'Les rôles sont révélés à l’élimination.'
                        : 'Les rôles des éliminés restent secrets jusqu’à la fin.',
                  ),
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
                    'Le Village gagne après élimination des loups et du Joueur de Flûte. La meute gagne à la majorité ou à égalité, après élimination du Loup Blanc. '
                    'Le Loup Blanc doit rester seul survivant. Le Joueur de Flûte gagne dès que tous les autres survivants sont charmés. '
                    'Un couple de camps opposés gagne si les deux amoureux sont les derniers survivants. L’Ange gagne s’il est condamné au premier vote. '
                    'Aucun survivant : partie nulle.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Le MDJ contrôle le chat général et le vote chronométré. '
                    'Chaque électeur autorisé peut modifier son bulletin jusqu’à la clôture, '
                    'voter pour un survivant (y compris lui-même) ou voter blanc. '
                    'Une absence de bulletin est une abstention. Une égalité, y compris '
                    'avec le vote blanc, n’élimine personne sauf si le Bouc émissaire est actif. Un vote blanc seul en tête n’élimine personne. '
                    'L’Idiot gracié et les joueurs écartés par le Bouc émissaire ne peuvent pas voter. '
                    'Les bulletins individuels restent privés ; les totaux sont révélés à la clôture.',
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
