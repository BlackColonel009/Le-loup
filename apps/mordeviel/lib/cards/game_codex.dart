import 'package:flutter/material.dart';
import 'package:local_host/card_variants.dart' show cardEdition;
import '../room_compatibility.dart';
import 'classic_role.dart';
import 'codex_grimoire.dart';

Future<void> showGameCodex(BuildContext context, Map<String, dynamic> room) =>
    showDialog<void>(
      context: context,
      builder: (context) => !hasRoomConfiguration(room)
          ? AlertDialog(
              title: const Text('Codex de la partie'),
              content: const IncompatibleRoomNotice(),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            )
          : Dialog.fullscreen(
              child: CodexGrimoire(chapters: codexChapters(room)),
            ),
    );

/// Only public composition is read, never assignments or private selections.
List<CodexChapter> codexChapters(Map<String, dynamic> room) {
  final pack = room['visual_pack'] as String? ?? 'classic';
  final styles = Map<String, String>.from(room['card_styles'] as Map? ?? {});
  final deck = room['deck'] as Map;
  final mayor =
      (room['game'] as Map?)?['mayor_edition'] as String? ??
      styles['mayor'] ??
      pack;
  String editionLabel(String edition) => switch (edition) {
    'intense' => 'Intense',
    'horror' => 'Horreur',
    _ => 'Classique',
  };
  return [
    CodexChapter(
      'Le pacte du village',
      [
        'Ambiance ${editionLabel(pack)} · Les attributions restent secrètes.',
        room['reveal_roles_on_death'] == true
            ? 'Les rôles sont révélés à l’élimination.'
            : 'Les rôles des éliminés restent secrets jusqu’à la fin.',
        room['seer_camp_only'] == true
            ? 'Variante : la Voyante découvre le camp uniquement.'
            : 'Règles classiques : la Voyante découvre le rôle exact.',
        room['reveal_rescuer'] == true
            ? 'Potion de vie : le joueur sauvé apprend en privé le pseudo de la Sorcière.'
            : 'Potion de vie : le joueur sauvé reçoit une seconde chance ; le pseudo de la Sorcière reste secret.',
        'En partie mixte, les pouvoirs suivent chaque carte et son édition. Les règles propres à une édition priment sur les repères classiques.',
        'Composition\n${[for (final role in classicRoles)
          if ((deck[role.id] as int? ?? 0) > 0) '${role.name} × ${deck[role.id]}'].join('\n')}',
      ].join('\n\n'),
    ),
    CodexChapter(
      'Le Maire · Fonction publique',
      '${editionLabel(mayor)}\n\n${configuredRole('mayor', edition: mayor).details}',
    ),
    for (final role in classicRoles)
      if ((deck[role.id] as int? ?? 0) > 0)
        CodexChapter('${role.name} × ${deck[role.id]}', () {
          final editions = [
            for (var i = 0; i < (deck[role.id] as int); i++)
              cardEdition(styles, role.id, i, pack),
          ];
          return 'Camp : ${role.camp} · ${role.phase}\n\n${[for (final edition in editions.toSet()) '${editionLabel(edition)} × ${editions.where((e) => e == edition).length}\n${configuredRole(role.id, seerCampOnly: room['seer_camp_only'] == true, edition: edition).details}'].join('\n\n')}';
        }()),
    const CodexChapter(
      'Les conditions de victoire',
      'Les tirs et réactions sont résolus avant de vérifier la victoire.\n\n'
          'Le Village gagne après élimination des loups et du Joueur de Flûte. La meute gagne à la majorité ou à égalité, après élimination du Loup Blanc.\n\n'
          'Le Loup Blanc doit rester seul survivant. Le Joueur de Flûte gagne dès que tous les autres survivants sont charmés.\n\n'
          'Un couple de camps opposés gagne si les deux amoureux sont les derniers survivants et n’ont pas rompu leur lien. L’Ange gagne au premier scrutin, ou au deuxième également pour l’Ange du sursis.\n\n'
          'Aucun survivant : partie nulle.',
    ),
    const CodexChapter(
      'Le conseil et les scrutins',
      'Le MDJ contrôle le chat général et le vote chronométré.\n\n'
          'Chaque électeur autorisé peut modifier son bulletin jusqu’à la clôture, voter pour un survivant (y compris lui-même) ou voter blanc. Une absence de bulletin est une abstention.\n\n'
          'Une égalité, y compris avec le vote blanc, n’élimine personne sauf si le Bouc émissaire est actif. Un vote blanc seul en tête n’élimine personne.\n\n'
          'Les variantes peuvent suspendre un bulletin, accorder un bulletin exceptionnel au Fou lucide ou permettre un second scrutin. Les précisions de chaque carte et du titre de Maire s’appliquent en partie mixte.\n\n'
          'Les bulletins individuels restent privés ; les totaux sont révélés à la clôture.',
    ),
  ];
}
