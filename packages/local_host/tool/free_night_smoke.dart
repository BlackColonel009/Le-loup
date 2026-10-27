import '../lib/src/night_game.dart';

void check(bool condition) {
  if (!condition) throw StateError('Free night check failed');
}

void rejected(void Function() action) {
  var failed = false;
  try {
    action();
  } on StateError {
    failed = true;
  }
  check(failed);
}

void main() {
  final game = NightGame({
    'w': 'werewolf',
    's': 'seer',
    't': 'witch',
    'a': 'villager',
    'b': 'villager',
  });
  game.startNight();
  check(!game.publicState.containsKey('night_actions'));
  rejected(() => game.advance());
  rejected(() => game.callNight('hunter'));
  rejected(() => game.callNight('witch'));
  game.callNight('wolves'); // Wolves first, not the seer.
  final oldRevision = game.revision;
  game.act('w', {
    'phase_revision': game.revision,
    'action': 'wolves.choose',
    'target': 'a',
  });
  game.advance();
  check(game.phase == 'sleep' && game.privateState('w')['can_act'] == false);
  rejected(() => game.callNight('wolves'));
  game.callNight('witch'); // Seer is still pending; no forced order.
  check(game.privateState('t')['victim'] == 'a');
  check(game.hostState['potion_used'] == false);
  rejected(
    () => game.act('w', {
      'phase_revision': oldRevision,
      'action': 'wolves.choose',
      'target': 'b',
    }),
  );
  game.act('t', {
    'phase_revision': game.revision,
    'action': 'witch.potions',
    'save': true,
  });
  check(game.hostState['potion_used'] == true);
  check(
    !game.publicState.containsKey('potion_used') &&
        !game.privateState('w').containsKey('potion_used'),
  );
  game.advance();
  game.callNight('seer');
  game.act('s', {
    'phase_revision': game.revision,
    'action': 'seer.inspect',
    'target': 'w',
  });
  game.advance();
  game.finishNight();
  check(game.phase == 'dawn' && game.deaths.isEmpty);
  final noSeer = NightGame({'w': 'werewolf', 'a': 'villager', 'b': 'villager'});
  noSeer.startNight();
  check(noSeer.nightActions.length == 1);
  noSeer.finishNight(); // Host can explicitly skip the unused actions.
  check(noSeer.deaths.isEmpty);
  final eliminated = NightGame({
    'w': 'werewolf',
    's': 'seer',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  });
  eliminated.startNight();
  eliminated.callNight('wolves');
  eliminated.act('w', {
    'phase_revision': eliminated.revision,
    'action': 'wolves.choose',
    'target': 's',
  });
  eliminated.advance();
  eliminated.finishNight();
  check(!eliminated.nightActions.any((a) => a['action'] == 'seer'));
  eliminated.advance();
  eliminated.startVote();
  eliminated.advance();
  eliminated.startNight();
  check(eliminated.nightActions.single['available'] == true);
  print(
    'Free night choices OK: order, dependencies, secrecy, stale actions, dawn.',
  );
}
