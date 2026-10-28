import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';

void act(
  NightGame g,
  String id,
  String action, {
  String? target,
  List<String>? targets,
}) => g.act(id, {
  'action': action,
  'phase_revision': g.revision,
  'target': target,
  if (targets != null) 'targets': targets,
});
void day(NightGame g) {
  g.startNight();
  g.finishNight();
  g.advance();
}

void elect(NightGame g, String mayor) {
  g.startVote();
  expect(g.phase, 'mayor_election');
  for (final id in g.alive) {
    act(g, id, 'vote.cast', target: mayor);
  }
  g.advance();
  expect(g.publicState['mayor'], mayor);
  expect(g.phase, 'day');
}

void main() {
  const roles = {
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'hunter',
    'd': 'seer',
    'e': 'villager',
  };
  test('Élection distincte, bulletin double, succession privée au Maire', () {
    final g = NightGame(roles, electMayor: true);
    day(g);
    elect(g, 'a');
    expect(g.roles['a'], 'villager');
    g.startVote();
    act(g, 'a', 'vote.cast', target: 'b');
    act(g, 'b', 'vote.cast', target: 'a');
    g.advance();
    expect((g.publicState['vote_result'] as Map)['counts'], {'b': 2, 'a': 1});
    expect(g.alive.contains('b'), false);
    g.startNight();
    g.callNight('wolves');
    act(g, 'w', 'wolves.choose', target: 'a');
    g.advance();
    g.finishNight();
    g.advance();
    expect(g.phase, 'mayor_succession');
    expect((g.privateState('a')['ability'] as Map)['action'], 'mayor.succeed');
    expect(g.privateState('e')['ability'], isNull);
    expect(
      () => act(g, 'e', 'mayor.succeed', targets: ['w']),
      throwsStateError,
    );
    act(g, 'a', 'mayor.succeed', targets: ['d']);
    expect(
      () => act(g, 'a', 'mayor.succeed', targets: ['w']),
      throwsStateError,
    );
    g.advance();
    expect(g.publicState['mayor'], 'd');
    expect(g.phase, 'day');
  });
  test(
    'Le Maire ne double pas son bulletin blanc ; égalité électorale sans mort',
    () {
      final g = NightGame(roles, electMayor: true);
      day(g);
      g.startVote();
      act(g, 'a', 'vote.cast', target: 'a');
      act(g, 'b', 'vote.cast', target: 'b');
      g.advance();
      expect(g.publicState['mayor'], isNull);
      expect(g.alive.length, 6);
      g.startVote();
      expect(g.phase, 'voting');
      g.advance();
      g.startNight();
      g.finishNight();
      g.advance();
      elect(g, 'a');
      g.startVote();
      act(g, 'a', 'vote.cast');
      g.advance();
      expect((g.publicState['vote_result'] as Map)['blank'], 1);
    },
  );
  test('Reconnaissance des Sœurs au premier appel, aucune fuite publique', () {
    final g = NightGame({...roles, 'a': 'sisters', 'b': 'sisters'});
    g.startNight();
    expect(g.privateState('a')['sister_ids'], isNull);
    g.callNight('sisters');
    expect(g.privateState('a')['sister_ids'], ['b']);
    expect(g.privateState('b')['sister_ids'], ['a']);
    expect(g.privateState('w')['sister_ids'], isNull);
    expect(g.publicState.containsKey('sister_ids'), false);
    expect(() => act(g, 'a', 'sisters.chat'), throwsStateError);
    g.advance();
    g.finishNight();
    g.advance();
    g.startVote();
    g.advance();
    g.startNight();
    expect(g.nightActions.any((a) => a['action'] == 'sisters'), false);
    expect(g.privateState('a')['sister_ids'], ['b']);
    expect(() => NightGame({...roles, 'a': 'sisters'}), throwsArgumentError);
  });
  test(
    'La victoire après le tir du Maire Chasseur prime sur la succession',
    () {
      final g = NightGame(roles, electMayor: true);
      day(g);
      elect(g, 'c');
      g.startVote();
      for (final id in g.alive) {
        act(g, id, 'vote.cast', target: 'c');
      }
      g.advance();
      expect(g.phase, 'hunter');
      act(g, 'c', 'hunter.shoot', target: 'w');
      g.advance();
      expect(g.phase, 'ended');
      expect(g.winner, 'village');
    },
  );
}
