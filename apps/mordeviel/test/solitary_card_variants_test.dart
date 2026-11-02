import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'card_variants_test.dart' show make, act, wolves;
import 'expanded_card_variants_test.dart' show vote;

void morning(NightGame g) {
  if (g.phase == 'sleep') g.finishNight();
  if (g.phase == 'dawn') g.advance();
}

void main() {
  test(
    'Fou lucide : un bulletin après la grâce, sans récupération permanente',
    () {
      final g = make(roles: {'i': 'idiot'}, editions: {'i': 'intense'});
      g.startNight();
      vote(g, 'i');
      g.startNight();
      morning(g);
      g.startVote();
      expect(g.privateState('i')['can_vote'], isFalse);
      act(g, 'i', 'idiot.ballot', targets: []);
      expect(g.privateState('i')['can_vote'], isTrue);
      act(g, 'i', 'vote.cast');
      g.advance();
      g.startNight();
      morning(g);
      g.startVote();
      expect(g.privateState('i')['can_vote'], isFalse);
      expect(() => act(g, 'i', 'idiot.ballot', targets: []), throwsStateError);
    },
  );

  test(
    'Fou contagieux : décision au résultat et restriction limitée au lendemain',
    () {
      final g = make(roles: {'i': 'idiot'}, editions: {'i': 'horror'});
      g.startNight();
      vote(g, 'i');
      expect(g.privateState('i')['can_act'], isTrue);
      act(g, 'i', 'idiot.contagion', targets: ['b']);
      expect(g.publicState['contagion_targets'], contains('b'));
      g.startNight();
      morning(g);
      g.startVote();
      expect(g.privateState('b')['can_vote'], isFalse);
      g.advance();
      g.startNight();
      morning(g);
      g.startVote();
      expect(g.privateState('b')['can_vote'], isTrue);
    },
  );

  test('Virtuose : trois vrais charmes une fois, sans seconde action', () {
    final g = make(roles: {'p': 'piper'}, editions: {'p': 'intense'});
    g.startNight();
    g.callNight('piper');
    act(g, 'p', 'piper.triple', targets: ['a', 'b', 'c']);
    expect(g.privateState('p')['charmed_ids'], containsAll(['a', 'b', 'c']));
    expect(
      () => act(g, 'p', 'piper.charm', targets: ['w', 'd']),
      throwsStateError,
    );
    expect(g.winner, isNull);
  });

  test(
    'Musicien des illusions : leurre privé, aucun faux charme dans la victoire',
    () {
      final g = make(roles: {'p': 'piper'}, editions: {'p': 'horror'});
      g.startNight();
      g.callNight('piper');
      act(g, 'p', 'piper.illusion', targets: ['w']);
      act(g, 'p', 'piper.charm', targets: ['a', 'b']);
      expect(g.privateState('a')['charmed_ids'], contains('w'));
      expect(g.privateState('p')['charmed_ids'], isNot(contains('w')));
      expect(g.privateState('w')['charmed'], isFalse);
      g.advance();
      vote(g, null);
      g.startNight();
      g.callNight('piper');
      act(g, 'p', 'piper.charm', targets: ['c', 'd']);
      expect(g.winner, isNull);
    },
  );

  test('Ange vigilant : échec au premier vote puis Éclaireur utilisable', () {
    final g = make(roles: {'q': 'angel'}, editions: {'q': 'intense'});
    g.startNight();
    vote(g, null);
    expect(g.roles['q'], 'villager');
    expect(g.editionOf('q'), 'intense');
    g.startNight();
    g.callNight('village_watch');
    act(g, 'q', 'villager.watch', targets: ['a']);
  });

  test(
    'Ange du sursis : protection interdite puis victoire au deuxième vote',
    () {
      final g = make(
        roles: {'q': 'angel', 'g': 'guardian'},
        editions: {'q': 'horror'},
      );
      g.startNight();
      g.callNight('guardian');
      expect(
        () => act(g, 'g', 'guardian.protect', targets: ['q']),
        throwsArgumentError,
      );
      g.advance();
      vote(g, null);
      expect(g.roles['q'], 'angel');
      g.startNight();
      vote(g, 'q');
      expect(g.winner, 'angel');
      expect(g.publicState['winner_ids'], ['q']);
    },
  );

  test('La potion de vie ne contourne pas le prix du sursis', () {
    final g = make(
      roles: {'q': 'angel', 'x': 'witch'},
      editions: {'q': 'horror'},
    );
    g.startNight();
    wolves(g, 'q');
    g.callNight('witch');
    expect(g.privateState('x')['save_blocked'], isTrue);
    expect(() => act(g, 'x', 'witch.potions', save: true), throwsStateError);
    expect(g.privateState('x')['life_available'], isTrue);
  });
}
