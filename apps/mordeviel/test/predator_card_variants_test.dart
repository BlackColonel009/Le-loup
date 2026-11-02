import 'package:flutter_test/flutter_test.dart';
import 'card_variants_test.dart' show make, act, wolves, nextNight;

void main() {
  test(
    'Alpha tenace : une dernière seconde attaque après la perte d’un loup',
    () {
      final g = make(
        roles: {
          'a': 'alpha_wolf',
          'w2': 'werewolf',
          'x': 'witch',
          'e': 'villager',
          'f': 'villager',
          'g': 'villager',
        },
        editions: {'a': 'intense'},
      );
      g.startNight();
      wolves(g, null);
      g.callNight('witch');
      act(g, 'x', 'witch.potions', kill: 'w2');
      g.advance();
      nextNight(g);
      wolves(g, 'b');
      g.callNight('alpha');
      act(g, 'a', 'alpha.choose', targets: ['c']);
      g.advance();
      nextNight(g);
      expect(() => g.callNight('alpha'), throwsStateError);
      expect(g.alive, isNot(contains('b')));
      expect(g.alive, isNot(contains('c')));
    },
  );

  test(
    'Alpha de la terreur : remplace l’attaque, interdit le bulletin mais pas la parole',
    () {
      final g = make(
        roles: {'q': 'alpha_wolf', 'e': 'villager'},
        editions: {'q': 'horror'},
      );
      g.startNight();
      wolves(g, 'a');
      g.callNight('alpha');
      act(g, 'q', 'alpha.terror', targets: ['b']);
      expect(
        () => act(g, 'q', 'alpha.choose', targets: ['c']),
        throwsStateError,
      );
      g.advance();
      g.finishNight();
      g.advance();
      expect(g.alive, contains('b'));
      g.act('b', {
        'action': 'day.chat',
        'phase_revision': g.revision,
        'text': 'Je peux toujours parler.',
      });
      g.startVote();
      expect(g.privateState('b')['can_vote'], isFalse);
      expect(() => act(g, 'b', 'vote.cast', target: 'w'), throwsStateError);
    },
  );

  test('Solitaire patient : déplace une attaque vers une nuit impaire', () {
    final g = make(roles: {'q': 'white_wolf'}, editions: {'q': 'intense'});
    g.startNight();
    nextNight(g);
    g.callNight('white_wolf');
    act(g, 'q', 'white_wolf.defer', targets: []);
    g.advance();
    nextNight(g);
    expect(g.night, 3);
    expect(g.alive, contains('w'));
    g.callNight('white_wolf');
    act(g, 'q', 'white_wolf.choose', targets: ['w']);
    expect(
      () => act(g, 'q', 'white_wolf.defer', targets: []),
      throwsStateError,
    );
    g.advance();
    g.finishNight();
    expect(g.alive, isNot(contains('w')));
  });

  test(
    'Dépeceur : cible extérieure, annonce privée à la meute et aucun second tir',
    () {
      final g = make(roles: {'q': 'white_wolf'}, editions: {'q': 'horror'});
      g.startNight();
      nextNight(g);
      g.callNight('white_wolf');
      act(g, 'q', 'white_wolf.outsider', targets: ['a']);
      expect(g.privateState('w')['role_notice'], contains('traître'));
      expect(g.privateState('b').containsKey('role_notice'), isFalse);
      expect(
        () => act(g, 'q', 'white_wolf.choose', targets: ['w']),
        throwsStateError,
      );
      g.advance();
      g.finishNight();
      expect(g.alive, isNot(contains('a')));
      expect(g.alive, contains('w'));
    },
  );

  test(
    'Meneur : conversion à la résolution, encore annulable par la potion de vie',
    () {
      for (final save in [false, true]) {
        final g = make(
          roles: {'p': 'wolf_father', 'x': 'witch', 'e': 'villager'},
          editions: {'p': 'intense'},
        );
        g.startNight();
        wolves(g, 'a');
        g.callNight('infection');
        act(g, 'p', 'infection.immediate', targets: ['a']);
        expect(g.privateState('a')['infected'], isFalse);
        g.advance();
        g.callNight('witch');
        act(g, 'x', 'witch.potions', save: save);
        g.advance();
        g.finishNight();
        expect(g.alive, contains('a'));
        expect(g.privateState('a')['infected'], !save);
      }
    },
  );

  test(
    'Père des ombres : dormance et activation anticipée sans nouvelle victime',
    () {
      final g = make(
        roles: {'p': 'wolf_father', 'e': 'villager', 'f': 'villager'},
        editions: {'p': 'horror'},
      );
      g.startNight();
      wolves(g, 'a');
      g.callNight('infection');
      act(g, 'p', 'infection.dormant', targets: ['a']);
      g.advance();
      nextNight(g);
      expect(g.privateState('a')['infected'], isFalse);
      wolves(g, null);
      g.callNight('infection');
      act(g, 'p', 'infection.activate', targets: ['a']);
      expect(g.privateState('a')['infected'], isTrue);
      expect(
        () => act(g, 'p', 'infection.convert', targets: ['b']),
        throwsStateError,
      );
    },
  );
}
