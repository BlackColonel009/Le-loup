import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'card_variants_test.dart' show make, act, wolves, nextNight;

void link(NightGame g) {
  g.startNight();
  g.callNight('cupid');
  act(g, 'p', 'cupid.link', targets: ['a', 'b']);
  g.advance();
  g.callNight('lovers');
}

void main() {
  test(
    'Tisseur : échange privé uniquement aux amoureux, effacé à la fermeture',
    () {
      final g = make(roles: {'p': 'cupid'}, editions: {'p': 'intense'});
      link(g);
      g.act('a', {
        'action': 'bond.chat',
        'phase_revision': g.revision,
        'text': 'Notre secret.',
      });
      expect(
        (g.privateState('b')['bond_chat']['messages'] as List).single['text'],
        'Notre secret.',
      );
      expect(g.privateState('w').containsKey('bond_chat'), isFalse);
      expect(g.publicState.toString(), isNot(contains('Notre secret.')));
      expect(g.hostState.toString(), isNot(contains('Notre secret.')));
      g.advance();
      expect(g.privateState('a').containsKey('bond_chat'), isFalse);
      expect(
        () => g.act('a', {
          'action': 'bond.chat',
          'phase_revision': g.revision,
          'text': 'Trop tard.',
        }),
        throwsStateError,
      );
    },
  );

  test(
    'Le délai privé dure 60 secondes actives et respecte la pause du MDJ',
    () {
      var now = DateTime.utc(2026, 11, 2);
      final g = NightGame(
        {
          'p': 'cupid',
          'w': 'werewolf',
          'a': 'villager',
          'b': 'villager',
          'c': 'villager',
        },
        editions: {'p': 'intense'},
        clock: () => now,
      );
      link(g);
      now = now.add(const Duration(seconds: 20));
      g.pause();
      now = now.add(const Duration(minutes: 2));
      expect(g.privateState('a')['bond_chat']['remaining_ms'], 40000);
      expect(g.privateState('a')['bond_chat']['open'], isFalse);
      g.resume();
      now = now.add(const Duration(seconds: 41));
      expect(g.privateState('a').containsKey('bond_chat'), isFalse);
      expect(
        () => g.act('a', {
          'action': 'bond.chat',
          'phase_revision': g.revision,
          'text': 'Expiré.',
        }),
        throwsStateError,
      );
    },
  );

  test('Pacte : un accord isolé ou un refus ne brise jamais le lien', () {
    final g = make(roles: {'p': 'cupid'}, editions: {'p': 'horror'});
    link(g);
    act(g, 'a', 'lovers.break_agree', targets: []);
    expect(g.privateState('a')['lover'], 'b');
    act(g, 'b', 'lovers.break_decline', targets: []);
    expect(g.privateState('a')['lover'], 'b');
    g.advance();
    wolves(g, 'a');
    g.finishNight();
    expect(g.alive, isNot(contains('a')));
    expect(g.alive, isNot(contains('b')));
  });

  test('Pacte : accord mutuel, deux votes perdus et fin des morts liées', () {
    final g = make(roles: {'p': 'cupid'}, editions: {'p': 'horror'});
    link(g);
    act(g, 'a', 'lovers.break_agree', targets: []);
    act(g, 'b', 'lovers.break_agree', targets: []);
    expect(g.privateState('a').containsKey('lover'), isFalse);
    g.advance();
    wolves(g, null);
    g.finishNight();
    g.advance();
    g.startVote();
    expect(g.privateState('a')['can_vote'], isFalse);
    expect(g.privateState('b')['can_vote'], isFalse);
    expect(g.privateState('c')['can_vote'], isTrue);
  });

  test(
    'Sœurs mixtes : consentement des deux, une seule rencontre et aucun tiers',
    () {
      final g = make(
        roles: {'s1': 'sisters', 's2': 'sisters'},
        editions: {'s1': 'intense'},
      );
      g.startNight();
      g.callNight('sisters');
      act(g, 's1', 'sisters.chat_agree', targets: []);
      expect(g.privateState('s1').containsKey('bond_chat'), isFalse);
      act(g, 's2', 'sisters.chat_agree', targets: []);
      expect(g.privateState('s1')['bond_chat']['open'], isTrue);
      expect(g.privateState('a').containsKey('bond_chat'), isFalse);
      g.advance();
      nextNight(g);
      expect(() => g.callNight('sisters'), throwsStateError);
    },
  );

  test('Serment : un accord isolé ne redirige pas la chasse', () {
    final g = make(
      roles: {'s1': 'sisters', 's2': 'sisters'},
      editions: {'s1': 'horror'},
    );
    g.startNight();
    g.callNight('sisters');
    act(g, 's1', 'sisters.transfer_agree', targets: ['s1']);
    g.advance();
    wolves(g, 's1');
    g.finishNight();
    expect(g.alive, isNot(contains('s1')));
    expect(g.alive, contains('s2'));
  });

  test(
    'Serment : attaque transférée, puis protection de la destinataire appliquée',
    () {
      for (final protect in [false, true]) {
        final g = make(
          roles: {
            's1': 'sisters',
            's2': 'sisters',
            if (protect) 'g': 'guardian',
          },
          editions: {'s1': 'horror'},
        );
        g.startNight();
        g.callNight('sisters');
        act(g, 's1', 'sisters.transfer_agree', targets: ['s1']);
        act(g, 's2', 'sisters.transfer_agree', targets: ['s1']);
        g.advance();
        if (protect) {
          g.callNight('guardian');
          act(g, 'g', 'guardian.protect', targets: ['s2']);
          g.advance();
        }
        wolves(g, 's1');
        g.finishNight();
        expect(g.alive, contains('s1'));
        expect(g.alive.contains('s2'), protect);
      }
    },
  );
}
