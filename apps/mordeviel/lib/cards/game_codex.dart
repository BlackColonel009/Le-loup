import 'package:flutter/material.dart';
import 'classic_role.dart';
import 'package:local_host/card_variants.dart' show cardEdition;
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
                  const ExpansionTile(
                    title: Text('Le Maire · Fonction publique'),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Élu le jour, il conserve son rôle secret. Son vote sur un suspect compte double ; son vote blanc compte une voix. À sa mort, il transmet son titre à un joueur vivant. Sans choix avant la fin du délai, une nouvelle élection est proposée le jour suivant. Une égalité à l’élection laisse le poste vacant ; elle n’élimine personne.',
                        ),
                      ),
                    ],
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
                              final styles = Map<String, String>.from(
                                room['card_styles'] as Map? ?? {},
                              );
                              final editions = [
                                for (
                                  var i = 0;
                                  i <
                                      ((room['deck'] as Map)[role.id] as int? ??
                                          0);
                                  i++
                                )
                                  cardEdition(
                                    styles,
                                    role.id,
                                    i,
                                    room['visual_pack'] as String? ?? 'classic',
                                  ),
                              ];
                              return [
                                for (final edition in editions.toSet())
                                  '${edition == 'classic'
                                      ? 'Classique'
                                      : edition == 'intense'
                                      ? 'Intense'
                                      : 'Horreur'} × ${editions.where((e) => e == edition).length}\n${configuredRole(role.id, seerCampOnly: room['seer_camp_only'] == true, edition: edition).details}',
                              ].join('\n\n');
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
