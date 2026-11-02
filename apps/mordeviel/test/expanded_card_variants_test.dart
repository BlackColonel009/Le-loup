import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'card_variants_test.dart' show make, act, wolves, nextNight;

void vote(NightGame g, String? target) {
  if (g.phase == 'sleep') g.finishNight();
  if (g.phase == 'dawn') g.advance();
  g.startVote();
  for (final id in g.alive.toList()) {
    if (g.privateState(id)['can_vote'] == true) {
      act(g, id, 'vote.cast', target: target);
    }
  }
  g.advance();
}

void main() {
  test('Éclaireur : l’observation seule ne rend pas un indice positif', () {
    final g = make(editions: {'a': 'intense'});
    g.startNight();
    g.callNight('village_watch');
    act(g, 'a', 'villager.watch', targets: ['b']);
    expect(
      () => act(g, 'a', 'villager.watch', targets: ['c']),
      throwsStateError,
    );
    expect(
      () => act(g, 'b', 'villager.watch', targets: ['c']),
      throwsStateError,
    );
    g.advance();
    g.finishNight();
    expect(g.privateState('a')['variant_result']['watched'], isFalse);
    expect(g.privateState('b').containsKey('variant_result'), isFalse);
    expect(g.publicState.containsKey('marked_houses'), isFalse);
  });

  test(
    'Veilleur : compte les pouvoirs sans révéler leurs auteurs et marque sa maison',
    () {
      final g = make(
        roles: {'s': 'seer', 'g': 'guardian'},
        editions: {'a': 'horror'},
      );
      g.startNight();
      g.callNight('village_watch');
      act(g, 'a', 'villager.watch', targets: ['b']);
      g.advance();
      g.callNight('seer');
      act(g, 's', 'seer.inspect', target: 'b');
      g.advance();
      g.callNight('guardian');
      act(g, 'g', 'guardian.protect', targets: ['b']);
      g.advance();
      g.finishNight();
      final clue = g.privateState('a')['variant_result'] as Map;
      expect(clue['count'], 2);
      expect(clue.toString(), isNot(contains('seer')));
      expect(g.publicState['marked_houses'], ['a']);
      expect(g.publicState.containsKey('variant_results'), isFalse);
      nextNight(g);
      expect(g.publicState.containsKey('marked_houses'), isFalse);
    },
  );

  test(
    'Alchimiste : poison au réveil suivant et potion de vie indépendante',
    () {
      final g = make(roles: {'x': 'witch'}, editions: {'x': 'intense'});
      g.startNight();
      wolves(g, 'b');
      g.callNight('witch');
      act(g, 'x', 'witch.delay', targets: ['a']);
      expect(g.privateState('x')['death_available'], isFalse);
      act(g, 'x', 'witch.potions', save: true);
      g.advance();
      g.finishNight();
      expect(g.alive, containsAll(['a', 'b']));
      nextNight(g);
      g.finishNight();
      expect(g.alive, isNot(contains('a')));
      expect((g.publicState['death_events'] as List).last['cause'], 'poison');
    },
  );

  test('Malédiction : un loup exécuté annule la condamnation', () {
    final g = make(
      roles: {'x': 'witch', 'w2': 'werewolf'},
      editions: {'x': 'horror'},
    );
    g.startNight();
    wolves(g, null);
    g.callNight('witch');
    act(g, 'x', 'witch.curse', targets: ['a']);
    expect(g.privateState('a')['role_notice'], contains('maudit'));
    g.advance();
    vote(g, 'w');
    expect(g.hostState['delayed_poisons'], isEmpty);
    g.startNight();
    expect(g.alive, contains('a'));
  });

  test('Malédiction : sans loup exécuté, le Chasseur réagit au crépuscule', () {
    final g = make(
      roles: {'x': 'witch', 'a': 'hunter'},
      editions: {'x': 'horror'},
    );
    g.startNight();
    wolves(g, null);
    g.callNight('witch');
    act(g, 'x', 'witch.curse', targets: ['a']);
    g.advance();
    vote(g, null);
    g.startNight();
    expect(g.phase, 'hunter');
    expect(g.alive, isNot(contains('a')));
    act(g, 'a', 'hunter.shoot', target: 'b');
    g.advance();
    expect(g.phase, 'sleep');
    expect(g.night, 2);
  });

  test(
    'Franc-tireur : renonce au tir et bloque une seule attaque de la meute',
    () {
      final g = make(roles: {'h': 'hunter'}, editions: {'h': 'intense'});
      g.startNight();
      wolves(g, 'h');
      g.finishNight();
      g.advance();
      expect(g.privateState('h')['can_act'], isTrue);
      act(g, 'h', 'hunter.ward', targets: ['a']);
      expect(() => act(g, 'h', 'hunter.shoot', target: 'w'), throwsStateError);
      g.advance();
      nextNight(g);
      wolves(g, 'a');
      g.finishNight();
      expect(g.alive, contains('a'));
      nextNight(g);
      wolves(g, 'a');
      g.finishNight();
      expect(g.alive, isNot(contains('a')));
    },
  );

  test(
    'Chasseur de monstres : deux tirs si le premier vise un loup, jamais trois',
    () {
      final g = make(
        roles: {'h': 'hunter', 'w2': 'werewolf'},
        editions: {'h': 'horror'},
      );
      g.startNight();
      wolves(g, 'h');
      g.finishNight();
      g.advance();
      act(g, 'h', 'hunter.shoot', target: 'w');
      expect(g.privateState('h')['hunter_done'], isFalse);
      act(g, 'h', 'hunter.shoot', target: 'w2');
      expect(g.privateState('h')['hunter_done'], isTrue);
      expect(() => act(g, 'h', 'hunter.shoot', target: 'a'), throwsStateError);
    },
  );
}
