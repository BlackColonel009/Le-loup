import 'classic_scenario_driver.dart';
import '../lib/src/night_game.dart';

void check(bool valid, String message) {
  if (!valid) throw StateError(message);
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

void act(
  NightGame game,
  String id,
  String action, {
  String? target,
  String? text,
}) => game.act(id, {
  'action': action,
  'phase_revision': game.revision,
  'target': target,
  'text': text,
});
void day(NightGame game) {
  game.startNight();
  while (game.phase != 'day') {
    nextClassic(game);
  }
}

void main() {
  var now = DateTime.utc(2026, 10, 26);
  const roles = {
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'h': 'hunter',
    't': 'witch',
  };
  final game = NightGame(roles, clock: () => now);
  day(game);
  rejects(() => game.startNight());
  act(game, 'a', 'day.chat', text: 'Bonjour au village');
  check((game.publicState['day_messages'] as List).length == 1, 'Chat général');
  game.setChatOpen(false);
  rejects(() => act(game, 'b', 'day.chat', text: 'Message fermé'));
  game.setChatOpen(true);
  game.startVote(seconds: 30);
  act(game, 'a', 'vote.cast', target: 'w');
  act(game, 'a', 'vote.cast', target: 'h');
  act(game, 'b', 'vote.cast', target: 'h');
  act(game, 't', 'vote.cast');
  check(
    game.publicState['votes_received'] == 3,
    'Un vote modifié compte deux fois',
  );
  check(
    !game.publicState.containsKey('counts') &&
        !game.publicState.containsKey('vote_result'),
    'Résultats visibles avant clôture',
  );
  check(
    game.privateState('a')['vote_target'] == 'h' &&
        game.privateState('b')['vote_target'] == 'h',
    'Bulletins privés',
  );
  game.pause();
  now = now.add(const Duration(minutes: 1));
  check(game.remainingMilliseconds == 30000, 'Pause du vote');
  rejects(() => act(game, 'w', 'vote.cast', target: 'a'));
  game.resume();
  now = now.add(const Duration(seconds: 31));
  game.expire();
  rejects(() => act(game, 'w', 'vote.cast', target: 'a'));
  nextClassic(game);
  check(
    game.phase == 'hunter' && game.winner == null,
    'Réaction du Chasseur après vote',
  );
  final result = game.publicState['vote_result'] as Map;
  check(
    result['blank'] == 1 &&
        result['abstentions'] == 2 &&
        result['eliminated'] == 'h',
    'Décompte blanc/abstention',
  );
  rejects(() => act(game, 'h', 'day.chat', text: 'Mort'));
  act(game, 'h', 'hunter.shoot', target: 'a');
  nextClassic(game);
  check(game.phase == 'vote_result', 'Retour après tir du Chasseur');
  rejects(() => act(game, 'a', 'vote.cast', target: 'w'));
  game.startNight();
  check(
    game.night == 2 && !game.alive.contains('a'),
    'Boucle de deuxième nuit',
  );
  nextClassic(game);
  act(game, 'w', 'wolves.choose', target: 't');
  nextClassic(game);
  nextClassic(game);
  nextClassic(game);
  check(game.winner == 'wolves', 'Victoire des loups après le cycle jour/nuit');

  final tie = NightGame(roles);
  day(tie);
  tie.startVote();
  act(tie, 'a', 'vote.cast', target: 'w');
  act(tie, 'b', 'vote.cast', target: 'a');
  nextClassic(tie);
  check(
    (tie.publicState['vote_result'] as Map)['reason'] == 'tie' &&
        tie.alive.length == 5,
    'Égalité',
  );
  final blank = NightGame(roles);
  day(blank);
  blank.startVote();
  act(blank, 'a', 'vote.cast');
  act(blank, 'b', 'vote.cast');
  act(blank, 'w', 'vote.cast', target: 'a');
  nextClassic(blank);
  check(
    (blank.publicState['vote_result'] as Map)['reason'] == 'blank' &&
        blank.alive.length == 5,
    'Vote blanc majoritaire',
  );
  final absent = NightGame(roles);
  day(absent);
  absent.startVote();
  nextClassic(absent);
  check(
    (absent.publicState['vote_result'] as Map)['abstentions'] == 5,
    'Abstention générale',
  );
  final win = NightGame(roles);
  day(win);
  win.startVote();
  act(win, 'a', 'vote.cast', target: 'w');
  nextClassic(win);
  check(win.winner == 'village', 'Victoire après vote');
  print(
    'Jour OK : chat, permissions, scrutin secret, modification, blanc, égalité, pause, délais, Chasseur et nuit suivante.',
  );
}
