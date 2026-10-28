import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'card_variants_test.dart' show make, act, wolves, nextNight;

void main() {
  test(
    'Le Gardien royal ne bloque pas le Loup Blanc ; le sacrifice peut sauver sa cible',
    () {
      for (final edition in ['intense', 'horror']) {
        final g = make(
          roles: {
            'g': 'guardian',
            'a': 'werewolf',
            'q': 'white_wolf',
            'e': 'villager',
            'f': 'villager',
          },
          editions: {'g': edition},
        );
        g.startNight();
        nextNight(g);
        g.callNight('guardian');
        act(
          g,
          'g',
          edition == 'intense' ? 'guardian.ward' : 'guardian.sacrifice',
          targets: ['a'],
        );
        g.advance();
        wolves(g, null);
        g.callNight('white_wolf');
        act(g, 'q', 'white_wolf.choose', targets: ['a']);
        g.advance();
        g.finishNight();
        expect(g.alive.contains('a'), edition == 'horror');
        expect(g.alive.contains('g'), edition == 'intense');
      }
    },
  );
  test('Un sacrifice n’arrête pas une infection sans attaque mortelle', () {
    final g = make(
      roles: {'g': 'guardian', 'f': 'wolf_father', 'e': 'villager'},
      editions: {'g': 'horror'},
    );
    g.startNight();
    g.callNight('guardian');
    act(g, 'g', 'guardian.sacrifice', targets: ['a']);
    g.advance();
    wolves(g, 'a');
    g.callNight('infection');
    act(g, 'f', 'infection.convert', targets: ['a']);
    g.advance();
    g.finishNight();
    expect(g.alive, containsAll(['g', 'a']));
    nextNight(g);
    expect(g.privateState('a')['infected'], isTrue);
  });
  test('Deux voiles sur une victime ne consomment qu’une charge', () {
    final g = make(
      roles: {'w2': 'werewolf'},
      editions: {'w': 'horror', 'w2': 'horror'},
    );
    g.startNight();
    g.callNight('wolves');
    for (final id in ['w', 'w2']) {
      act(g, id, 'wolves.veil', targets: []);
      act(g, id, 'wolves.choose', target: 'a');
    }
    g.advance();
    g.finishNight();
    nextNight(g);
    g.callNight('wolves');
    expect(g.privateState('w')['variant_abilities'], isEmpty);
    expect(g.privateState('w2')['variant_abilities'], isNotEmpty);
  });
  test('La victoire révèle immédiatement une carte voilée', () {
    final g = NightGame(
      {'w': 'werewolf', 'a': 'villager', 'b': 'villager'},
      editions: {'w': 'horror'},
    );
    g.startNight();
    g.callNight('wolves');
    act(g, 'w', 'wolves.veil', targets: []);
    act(g, 'w', 'wolves.choose', target: 'a');
    g.advance();
    g.finishNight();
    expect(
      (g.publicState['death_events'] as List).single.containsKey('role'),
      isFalse,
    );
    g.advance();
    expect(g.phase, 'ended');
    expect((g.publicState['death_events'] as List).single['role'], 'villager');
  });
  test(
    'Le sacrifice conserve l’origine nocturne dans l’historique final, sans fuite avant la fin',
    () {
      final g = make(roles: {'g': 'guardian'}, editions: {'g': 'horror'});
      g.startNight();
      g.callNight('guardian');
      act(g, 'g', 'guardian.sacrifice', targets: ['a']);
      g.advance();
      wolves(g, 'a');
      g.finishNight();
      expect(g.publicState.containsKey('history'), isFalse);
      expect(
        (g.publicState['death_events'] as List).single.containsKey(
          'redirected_from',
        ),
        isFalse,
      );
      g.advance();
      g.startVote();
      for (final id in g.alive.toList()) {
        act(g, id, 'vote.cast', target: 'w');
      }
      g.advance();
      expect(g.phase, 'ended');
      final death = (g.publicState['history'] as List).firstWhere(
        (e) => e['kind'] == 'death' && e['target'] == 'g',
      );
      expect(death['source_cause'], 'night');
      expect(death['redirected_from'], 'a');
    },
  );
}
