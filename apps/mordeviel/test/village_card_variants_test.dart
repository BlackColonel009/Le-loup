import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'card_variants_test.dart' show make, act, wolves, nextNight;

void main() {
  test(
    'Le Traqueur détecte aussi une résistance transmise dans un jeu mixte',
    () {
      final g = make(
        roles: {'e': 'elder'},
        editions: {'w': 'intense', 'e': 'intense'},
      );
      g.startNight();
      g.callNight('elder_watch');
      act(g, 'e', 'elder.transfer', targets: ['a']);
      g.advance();
      g.callNight('wolves');
      act(g, 'w', 'wolves.scent', targets: ['a']);
      expect(g.privateState('w')['variant_result']['protected'], isTrue);
      expect(g.privateState('a').containsKey('variant_result'), isFalse);
    },
  );

  test(
    'Espionne : deux murmures distincts, sans leurs auteurs et avec le risque classique',
    () {
      var now = DateTime.utc(2026, 11, 2);
      final g = NightGame(
        {
          'w': 'werewolf',
          'f': 'little_girl',
          'a': 'villager',
          'b': 'villager',
          'c': 'villager',
        },
        editions: {'f': 'intense'},
        clock: () => now,
        chanceDraw: (_) => 0,
      );
      g.startNight();
      g.callNight('wolves');
      g.act('w', {
        'action': 'wolves.chat',
        'phase_revision': g.revision,
        'text': 'Premier murmure',
      });
      now = now.add(const Duration(seconds: 2));
      g.act('w', {
        'action': 'wolves.chat',
        'phase_revision': g.revision,
        'text': 'Second murmure',
      });
      act(g, 'f', 'little_girl.peek', targets: []);
      expect(g.privateState('f')['peek_message'], contains('Premier murmure'));
      expect(g.privateState('f')['peek_message'], contains('Second murmure'));
      expect(g.privateState('w')['spotted_girls'], contains('f'));
      expect(g.privateState('b').containsKey('peek_message'), isFalse);
    },
  );

  test(
    'Petite Ombre : le faux murmure ne révèle pas son auteur ni un accès à la meute',
    () {
      final g = NightGame(
        {
          'w': 'werewolf',
          'f': 'little_girl',
          'a': 'villager',
          'b': 'villager',
          'c': 'villager',
        },
        editions: {'f': 'horror'},
        chanceDraw: (n) => n - 1,
      );
      g.startNight();
      g.callNight('wolves');
      g.act('f', {
        'action': 'little_girl.false_whisper',
        'phase_revision': g.revision,
        'targets': [],
        'text': 'Les ombres vous observent.',
      });
      final messages = g.privateState('w')['messages'] as List;
      expect(messages.single['author'], 'unknown');
      expect(messages.single['text'], contains('Présence inconnue'));
      expect(g.privateState('f')['is_pack'], isFalse);
      expect(g.voiceAccess('f')['channel'], isNull);
      expect(g.privateState('b').containsKey('messages'), isFalse);
      expect(
        () => act(g, 'f', 'little_girl.false_whisper', targets: []),
        throwsStateError,
      );
      act(g, 'f', 'little_girl.peek', targets: []);
    },
  );

  test(
    'Ancien protecteur : sa résistance est transmise, sans être dupliquée',
    () {
      final g = make(roles: {'e': 'elder'}, editions: {'e': 'intense'});
      g.startNight();
      g.callNight('elder_watch');
      act(g, 'e', 'elder.transfer', targets: ['a']);
      g.advance();
      wolves(g, 'a');
      g.finishNight();
      expect(g.alive, contains('a'));
      nextNight(g);
      wolves(g, 'e');
      g.finishNight();
      expect(g.alive, isNot(contains('e')));
    },
  );

  test(
    'Ancien des présages : prédiction publique, sauvetage et perte de sa résistance',
    () {
      final g = make(roles: {'e': 'elder'}, editions: {'e': 'horror'});
      g.startNight();
      g.callNight('elder_watch');
      act(g, 'e', 'elder.presage', targets: ['a']);
      expect((g.publicState['presages'] as List).single['target'], 'a');
      g.advance();
      wolves(g, 'a');
      g.finishNight();
      expect(g.alive, contains('a'));
      nextNight(g);
      wolves(g, 'e');
      g.finishNight();
      expect(g.alive, isNot(contains('e')));
    },
  );
}
