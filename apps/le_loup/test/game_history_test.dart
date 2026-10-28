import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/src/night_game.dart';
import 'package:le_loup/village/game_history.dart';

void act(
  NightGame g,
  String id,
  String command, {
  String? target,
  bool save = false,
  String? kill,
  String? text,
}) => g.act(id, {
  'action': command,
  'phase_revision': g.revision,
  'target': target,
  'save': save,
  'kill': kill,
  'text': text,
});

void main() {
  test(
    'Historique complet sur deux manches, secret puis révélé et détaché du moteur',
    () {
      final g = NightGame({
        'w': 'werewolf',
        's': 'seer',
        'a': 'villager',
        'b': 'villager',
        't': 'witch',
      });
      for (var round = 1; round <= 2; round++) {
        g.startNight();
        g.callNight('seer');
        act(g, 's', 'seer.inspect', target: 'w');
        expect(g.privateState('s')['confirmed_selection']['target'], 'w');
        expect(g.privateState('a').containsKey('confirmed_selection'), isFalse);
        expect(g.publicState.containsKey('confirmed_selections'), isFalse);
        g.advance();
        g.callNight('wolves');
        if (round == 1) {
          act(g, 'w', 'wolves.chat', text: 'secret jamais archivé');
        }
        act(g, 'w', 'wolves.choose', target: round == 1 ? 'a' : 't');
        g.advance();
        g.callNight('witch');
        act(
          g,
          't',
          'witch.potions',
          save: round == 1,
          kill: round == 1 ? 'b' : null,
        );
        g.advance();
        expect(g.publicState.containsKey('history'), isFalse);
        g.finishNight();
        g.advance();
        expect(g.phase, 'day');
        g.startVote();
        for (final id in g.alive.toList()) {
          act(g, id, 'vote.cast', target: round == 1 ? null : 'w');
        }
        if (round == 1) {
          act(g, 'a', 'vote.cast', target: 's');
          act(g, 'a', 'vote.cast');
        }
        expect(g.publicState.containsKey('history'), isFalse);
        g.advance();
      }
      expect(g.phase, 'ended');
      final history = g.publicState['history'] as List;
      expect(history.where((e) => e['night'] == 1), isNotEmpty);
      expect(history.where((e) => e['night'] == 2), isNotEmpty);
      expect(history.where((e) => e['kind'] == 'vote_result'), hasLength(2));
      expect(
        history.where(
          (e) =>
              e['action'] == 'vote.cast' &&
              e['actor'] == 'a' &&
              e['night'] == 1,
        ),
        hasLength(3),
      );
      expect(
        history.where((e) => e['effect'] == 'saved').single['target'],
        'a',
      );
      expect(
        history.where((e) => e['cause'] == 'poison').single['target'],
        'b',
      );
      expect(
        history
            .where((e) => e['action'] == 'seer.inspect')
            .first['vision']['value'],
        'werewolf',
      );
      expect(history.toString(), isNot(contains('secret jamais archivé')));
      history.first['kind'] = 'tampered';
      expect(g.publicState['history'].first['kind'], isNot('tampered'));
    },
  );

  testWidgets('Le bilan affiche les manches, actions et bulletins nominatifs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameHistoryScreen(
          players: [
            {'id': 's', 'nickname': 'Alice'},
            {'id': 'w', 'nickname': 'Basile'},
          ],
          game: {
            'phase': 'ended',
            'history': [
              {
                'kind': 'action',
                'night': 1,
                'phase': 'seer',
                'actor': 's',
                'role': 'seer',
                'action': 'seer.inspect',
                'target': 'w',
                'vision': {'kind': 'role', 'value': 'werewolf'},
              },
              {
                'kind': 'vote_result',
                'night': 1,
                'phase': 'voting',
                'ballots': {'s': 'w', 'w': null},
                'reason': 'tie',
                'cast': 2,
                'eligible': 2,
                'blank': 1,
              },
            ],
          },
        ),
      ),
    );
    expect(find.text('Nuit 1'), findsOneWidget);
    expect(
      find.textContaining('Alice (Voyante) observe Basile'),
      findsOneWidget,
    );
    expect(find.textContaining('Alice → Basile'), findsOneWidget);
    expect(find.textContaining('Basile → vote blanc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Le bilan refuse un historique prématuré même fourni par erreur',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GameHistoryScreen(
            game: {
              'phase': 'wolves',
              'history': [
                {'kind': 'action', 'actor': 'Secret'},
              ],
            },
            players: [],
          ),
        ),
      );
      expect(find.textContaining('Le bilan sera disponible'), findsOneWidget);
      expect(find.textContaining('Secret'), findsNothing);
    },
  );
}
