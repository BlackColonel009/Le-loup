import 'classic_scenario_driver.dart';
import '../lib/src/night_game.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void rejects(void Function() action) {
  var refused = false;
  try {
    action();
  } catch (_) {
    refused = true;
  }
  check(refused, 'Une action interdite a été acceptée.');
}

NightGame prepare({required bool reveal, required DateTime Function() clock}) {
  final game = NightGame(
    {
      'w': 'werewolf',
      'a': 'villager',
      'b': 'villager',
      'h': 'hunter',
      't': 'witch',
    },
    revealOnDeath: reveal,
    clock: clock,
  );
  game.startNight();
  while (game.phase != 'day') {
    nextClassic(game);
  }
  game.startVote();
  game.act('a', {
    'action': 'vote.cast',
    'phase_revision': game.revision,
    'target': 'b',
  });
  nextClassic(game);
  return game;
}

void main() {
  var now = DateTime.utc(2026, 10, 26);
  final game = prepare(reveal: true, clock: () => now);
  final events = game.publicState['death_events'] as List;
  check(
    events.length == 1 && events.single['role'] == 'villager',
    'Carte éliminée non révélée',
  );
  check(
    (game.publicState['revealed_roles'] as Map).length == 1 &&
        !(game.publicState['revealed_roles'] as Map).containsKey('w'),
    'Rôle vivant révélé',
  );
  final eligible = game.alive.length;
  game.spinSentence(3);
  check(
    (game.publicState['sentence'] as Map)['label'] == 'Cachot',
    'Sentence incorrecte',
  );
  check(
    game.alive.length == eligible && game.winner == null,
    'La roue a modifié les règles',
  );
  rejects(() => game.spinSentence(1));
  rejects(() => game.startNight());
  now = now.add(const Duration(seconds: 5));
  game.startNight();
  check(
    !game.publicState.containsKey('sentence') &&
        (game.publicState['death_events'] as List).length == 1,
    'Historique perdu ou roue conservée',
  );
  final hidden = prepare(reveal: false, clock: () => now);
  check(
    !(hidden.publicState['death_events'] as List).single.containsKey('role') &&
        !hidden.publicState.containsKey('revealed_roles'),
    'Rôle secret divulgué',
  );
  check(
    hidden.privateState('b')['role'] == 'villager',
    'La victime perd sa carte privée',
  );
  final night = NightGame({
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  }, revealOnDeath: true);
  night.startNight();
  nextClassic(night);
  night.act('w', {
    'action': 'wolves.choose',
    'phase_revision': night.revision,
    'target': 'a',
  });
  check(
    (night.publicState['death_events'] as List).isEmpty,
    'Mort annoncée avant le réveil',
  );
  nextClassic(night);
  check(
    (night.publicState['death_events'] as List).single['cause'] == 'night',
    'Annonce nocturne absente',
  );
  rejects(() => night.spinSentence(0));
  print(
    'Cérémonies OK : révélations limitées aux morts, mode secret, annonces au réveil, roue unique et purement visuelle.',
  );
}
