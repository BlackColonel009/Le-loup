import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'card_variants_test.dart' show make, act, wolves;
import 'expanded_card_variants_test.dart' show vote;

void morning(NightGame g) {
  if (g.phase == 'sleep') g.finishNight();
  if (g.phase == 'dawn') g.advance();
}

NightGame withMayor(
  String edition, {
  String role = 'villager',
  String cardEdition = 'classic',
}) {
  final g = NightGame(
    {
      'w': 'werewolf',
      'm': role,
      'a': 'villager',
      'b': 'villager',
      'c': 'villager',
      'd': 'villager',
      'e': 'villager',
    },
    electMayor: true,
    mayorEdition: edition,
    editions: {'m': cardEdition},
  );
  g.startNight();
  morning(g);
  g.startVote();
  for (final id in g.alive) {
    act(g, id, 'vote.cast', target: 'm');
  }
  g.advance();
  return g;
}

void main() {
  test('Un Maire Fou lucide garde les actions de son titre et de sa carte', () {
    final g = withMayor('intense', role: 'idiot', cardEdition: 'intense');
    vote(g, 'm');
    g.startNight();
    morning(g);
    g.startVote();
    final actions = (g.privateState('m')['variant_abilities'] as List).map(
      (a) => a['action'],
    );
    expect(actions, containsAll(['mayor.strategy', 'idiot.ballot']));
    act(g, 'm', 'mayor.strategy', targets: []);
    act(g, 'm', 'idiot.ballot', targets: []);
    expect(g.privateState('m')['can_vote'], isTrue);
    act(g, 'm', 'vote.cast', target: 'a');
    act(g, 'w', 'vote.cast', target: 'b');
    g.advance();
    expect(g.publicState['second_ballot'], isTrue);
    expect(g.privateState('m')['can_vote'], isTrue);
  });

  test(
    'Médiateur : second scrutin sans son bulletin, nouvelle égalité fatale',
    () {
      final g = make(roles: {'z': 'scapegoat'}, editions: {'z': 'intense'});
      g.startNight();
      morning(g);
      g.startVote();
      act(g, 'w', 'vote.cast', target: 'a');
      act(g, 'c', 'vote.cast', target: 'b');
      g.advance();
      expect(g.phase, 'mediation');
      expect(g.privateState('z')['can_act'], isTrue);
      act(g, 'z', 'scapegoat.revote', targets: []);
      expect(g.phase, 'voting');
      expect(g.privateState('z')['can_vote'], isFalse);
      expect(g.publicState['second_ballot'], isTrue);
      act(g, 'w', 'vote.cast', target: 'a');
      act(g, 'c', 'vote.cast', target: 'b');
      g.advance();
      expect(g.alive, isNot(contains('z')));
      expect(g.phase, 'scapegoat');
    },
  );

  test(
    'Médiateur : accepter son sacrifice ne crée pas de scrutin supplémentaire',
    () {
      final g = make(roles: {'z': 'scapegoat'}, editions: {'z': 'intense'});
      g.startNight();
      morning(g);
      g.startVote();
      act(g, 'w', 'vote.cast', target: 'a');
      act(g, 'c', 'vote.cast', target: 'b');
      g.advance();
      act(g, 'z', 'scapegoat.accept', targets: []);
      expect(g.alive, isNot(contains('z')));
      expect(g.phase, 'scapegoat');
    },
  );

  test(
    'Bouc maudit : révélation volontaire du camp sans supprimer les autres choix',
    () {
      final g = make(roles: {'z': 'scapegoat'}, editions: {'z': 'horror'});
      g.startNight();
      vote(g, 'z');
      act(g, 'z', 'scapegoat.mark', targets: ['b']);
      act(g, 'b', 'mark.reveal', targets: []);
      expect(g.publicState['revealed_camps'], {'b': 'village'});
      act(g, 'z', 'scapegoat.voters', targets: g.alive.toList());
      g.advance();
      g.startNight();
      morning(g);
      g.startVote();
      expect(g.privateState('b')['can_vote'], isTrue);
    },
  );

  test(
    'Bouc maudit : garder son secret entraîne la perte du prochain vote',
    () {
      final g = make(roles: {'z': 'scapegoat'}, editions: {'z': 'horror'});
      g.startNight();
      vote(g, 'z');
      act(g, 'z', 'scapegoat.mark', targets: ['b']);
      act(g, 'b', 'mark.refuse', targets: []);
      expect(g.publicState.containsKey('revealed_camps'), isFalse);
      g.advance();
      g.startNight();
      morning(g);
      g.startVote();
      expect(g.privateState('b')['can_vote'], isFalse);
    },
  );

  test(
    'Maire stratège : titre indépendant du rôle, vote simple et second scrutin unique',
    () {
      final g = withMayor('intense');
      expect(g.editionOf('m'), 'classic');
      g.startVote();
      act(g, 'm', 'mayor.strategy', targets: []);
      act(g, 'm', 'vote.cast', target: 'a');
      act(g, 'w', 'vote.cast', target: 'b');
      g.advance();
      expect(g.phase, 'voting');
      expect(g.publicState['second_ballot'], isTrue);
      act(g, 'm', 'vote.cast', target: 'a');
      act(g, 'w', 'vote.cast', target: 'b');
      act(g, 'c', 'vote.cast', target: 'b');
      g.advance();
      expect(g.publicState['vote_result']['counts'], {'a': 1, 'b': 2});
      expect(g.alive, isNot(contains('b')));
      expect(g.phase, 'vote_result');
    },
  );

  test(
    'Testament : secret avant la mort, public et appliqué après celle-ci',
    () {
      final g = withMayor('horror');
      act(g, 'm', 'mayor.testament', targets: ['b']);
      expect(g.publicState.containsKey('mayor_testament'), isFalse);
      expect(g.hostState['sealed_testament'], 'b');
      vote(g, 'm');
      expect(g.publicState['mayor'], 'b');
      expect(g.publicState['mayor_testament']['valid'], isTrue);
      expect(g.hostState['sealed_testament'], isNull);
    },
  );

  test(
    'Un successeur déjà mort rouvre l’élection au lieu de bloquer la partie',
    () {
      final g = withMayor('horror');
      act(g, 'm', 'mayor.testament', targets: ['b']);
      vote(g, 'b');
      g.startNight();
      wolves(g, 'm');
      g.finishNight();
      g.advance();
      expect(g.phase, 'day');
      expect(g.publicState['mayor'], isNull);
      expect(g.publicState['mayor_election_needed'], isTrue);
      expect(g.publicState['mayor_testament']['valid'], isFalse);
    },
  );
}
