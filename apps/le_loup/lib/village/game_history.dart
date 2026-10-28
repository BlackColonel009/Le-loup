import 'package:flutter/material.dart';
import '../cards/classic_role.dart';

Future<void> showGameHistory(BuildContext context, Map game, List players) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GameHistoryScreen(game: game, players: players),
      ),
    );

class GameHistoryScreen extends StatelessWidget {
  const GameHistoryScreen({
    super.key,
    required this.game,
    required this.players,
  });
  final Map game;
  final List players;
  String name(dynamic id) =>
      players
          .where((p) => p['id'] == id)
          .map((p) => p['nickname'] as String)
          .firstOrNull ??
      'Personne';
  String names(dynamic ids) => (ids as List? ?? []).map(name).join(', ');
  String role(dynamic id) => id is String ? configuredRole(id).name : 'Joueur';

  String describe(Map e) {
    final actor = '${name(e['actor'])} (${role(e['role'])})';
    final target = name(e['target']);
    final selected = names(e['targets']);
    switch (e['kind']) {
      case 'phase':
        return e['label'] as String;
      case 'sentence':
        return '$target : sentence « ${e['label']} ».';
      case 'death':
        return '$target (${role(e['role'])}) est éliminé : ${switch (e['cause']) {
          'night' => 'attaque de la meute',
          'poison' => 'potion de mort',
          'hunter' => 'tir du Chasseur',
          'love' => 'mort de chagrin',
          'white_wolf' => 'attaque du Loup Blanc',
          _ => 'vote du village',
        }}.';
      case 'effect':
        return switch (e['effect']) {
          'infection' => '$target rejoint la meute.',
          'angel_becomes_villager' =>
            '$target devient Simple Villageois après le premier vote.',
          'infection_pending' =>
            '$target est infecté ; conversion prévue la nuit suivante.',
          'elder_curse' =>
            'La malédiction de l’Ancien désactive les pouvoirs du Village.',
          'elder_resists' =>
            '$target résiste à sa première attaque de la meute.',
          'protected' =>
            'La protection du Salvateur bloque l’attaque sur $target.',
          'saved' =>
            'La potion de vie sauve $target et annule son éventuelle infection.',
          _ => 'Sans accord unanime, la meute n’élimine personne.',
        };
      case 'vote_result':
        final details = <String>[
          for (final b in (e['ballots'] as Map? ?? {}).entries)
            '${name(b.key)} → ${b.value == null ? 'vote blanc' : name(b.value)}',
          if ((e['abstained'] as List? ?? []).isNotEmpty)
            'Abstentions : ${names(e['abstained'])}',
          'Résultat : ${switch (e['reason']) {
            'tie' => 'égalité, aucune élimination',
            'blank' => 'le vote blanc l’emporte',
            'abstention' => 'aucun bulletin reçu',
            'scapegoat' => 'égalité : le Bouc émissaire est désigné',
            'idiot_grace' => '${name(e['graced'])} est gracié et perd son vote',
            _ => '${name(e['eliminated'])} est désigné',
          }}.',
          '${e['cast']} bulletin(s) / ${e['eligible']} votant(s) · ${e['blank']} vote(s) blanc(s).',
        ];
        return details.join('\n');
    }
    return switch (e['action']) {
      'vote.cast' =>
        '$actor → ${e['target'] == null ? 'vote blanc' : target} (bulletin confirmé).',
      'wolves.choose' => '$actor propose $target à la meute.',
      'seer.inspect' =>
        '$actor observe $target : ${e['vision']?['kind'] == 'camp' ? switch (e['vision']?['value']) {
                'wolves' => 'Loups-Garous',
                'village' => 'Village',
                _ => 'Solitaire',
              } : role(e['vision']?['value'])}.',
      'witch.potions' =>
        '$actor : ${e['save'] == true ? 'potion de vie sur ${name(e['victim'])}' : 'aucune potion de vie'} ; ${e['kill'] != null ? 'potion de mort sur ${name(e['kill'])}' : 'aucune potion de mort'}.',
      'hunter.shoot' => '$actor tire sur $target.',
      'metamorph.swap' =>
        '$actor échange les cartes de $selected.${e['new_roles'] is Map ? ' Nouveaux rôles : ${(e['new_roles'] as Map).entries.map((r) => '${name(r.key)} : ${role(r.value)}').join(', ')}.' : ''}',
      'cupid.link' => '$actor lie les amoureux : $selected.',
      'guardian.protect' => '$actor protège $selected.',
      'alpha.choose' => '$actor choisit une seconde victime : $selected.',
      'white_wolf.choose' => '$actor attaque $selected.',
      'infection.convert' => '$actor tente d’infecter $selected.',
      'piper.charm' => '$actor charme $selected.',
      'scapegoat.voters' =>
        '$actor autorise à voter le lendemain : ${selected.isEmpty ? 'personne' : selected}.',
      'little_girl.peek' =>
        '$actor espionne la meute : ${e['spotted'] == true ? 'repérée' : 'non repérée'}.',
      'night.pass' => '$actor passe son action.',
      _ => '$actor confirme une action.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ended = game['phase'] == 'ended';
    final events = ended ? game['history'] as List? ?? [] : [];
    return Scaffold(
      appBar: AppBar(title: const Text('Historique de la partie')),
      body: !ended
          ? const Center(
              child: Text('Le bilan sera disponible à la fin de la partie.'),
            )
          : events.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun historique détaillé disponible pour cette partie. Les nouvelles parties l’enregistreront après la mise à jour du serveur.',
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final event = events[i] as Map;
                final previous = i == 0 ? null : events[i - 1] as Map;
                final night = event['night'] ?? 0;
                final phase = event['phase'];
                final daytime = [
                  'dawn',
                  'hunter',
                  'scapegoat',
                  'day',
                  'voting',
                  'vote_result',
                  'ended',
                ].contains(phase);
                final heading =
                    previous == null ||
                    previous['night'] != night ||
                    ['dawn', 'sleep'].contains(phase) &&
                        previous['phase'] != phase;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (heading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          night == 0
                              ? 'Préparation'
                              : '${daytime ? 'Jour' : 'Nuit'} $night',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: SelectableText(describe(event)),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
