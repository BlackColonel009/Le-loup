import '../lib/src/night_game.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void rejects(void Function() action) {
  var rejected = false;
  try {
    action();
  } on StateError {
    rejected = true;
  } on ArgumentError {
    rejected = true;
  }
  check(rejected, 'Forbidden action accepted');
}

void act(
  NightGame g,
  String id,
  String command, {
  String? target,
  List<String>? targets,
  bool save = false,
  String? kill,
  String? text,
}) => g.act(id, {
  'phase_revision': g.revision,
  'action': command,
  'target': target,
  'targets': targets,
  'save': save,
  'kill': kill,
  'text': text,
});
void close(NightGame g) => g.advance();
void wolves(NightGame g, List<String> ids, String target) {
  g.callNight('wolves');
  for (final id in ids) {
    act(g, id, 'wolves.choose', target: target);
  }
  close(g);
}

void dawn(NightGame g) {
  g.finishNight();
  check(g.phase == 'dawn', 'Dawn missing');
}

void day(NightGame g) {
  dawn(g);
  close(g);
  check(g.phase == 'day', 'Day missing');
}

void vote(NightGame g, String? target) {
  g.startVote();
  for (final id in g.alive.toList()) {
    if (g.privateState(id)['can_vote'] == true)
      act(g, id, 'vote.cast', target: target);
  }
  close(g);
}

void main() {
  final swap = NightGame({
    'm': 'metamorph',
    's': 'seer',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
  });
  swap.startNight();
  rejects(() => swap.callNight('wolves'));
  swap.callNight('metamorph');
  rejects(() => act(swap, 'm', 'metamorph.swap', targets: ['m', 'm']));
  act(swap, 'm', 'metamorph.swap', targets: ['m', 's']);
  check(
    swap.roles['m'] == 'seer' && swap.roles['s'] == 'metamorph',
    'Role exchange',
  );
  check(
    swap.privateState('s')['role_notice'] != null &&
        !swap.publicState.containsKey('role_notice'),
    'Private exchange notice',
  );
  rejects(() => act(swap, 's', 'metamorph.swap', targets: ['a', 'b']));
  close(swap);
  swap.callNight('seer');
  act(swap, 'm', 'seer.inspect', target: 'w');
  rejects(() => act(swap, 's', 'seer.inspect', target: 'a'));

  final love = NightGame({
    'c': 'cupid',
    'h': 'hunter',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'd': 'villager',
  });
  love.startNight();
  love.callNight('cupid');
  act(love, 'c', 'cupid.link', targets: ['h', 'a']);
  close(love);
  check(
    love.privateState('a')['lover'] == 'h' &&
        !love.publicState.containsKey('lovers'),
    'Private lovers',
  );
  wolves(love, ['w'], 'a');
  dawn(love);
  check(
    love.deaths.toSet().containsAll(['h', 'a']) && love.winner == null,
    'Lover death chain',
  );
  close(love);
  check(love.phase == 'hunter', 'Lover hunter reaction');
  act(love, 'h', 'hunter.shoot', target: 'w');
  close(love);
  check(love.winner == 'village', 'Victory after hunter');

  final pair = NightGame({
    'c': 'cupid',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
  });
  pair.startNight();
  pair.callNight('cupid');
  act(pair, 'c', 'cupid.link', targets: ['w', 'a']);
  close(pair);
  wolves(pair, ['w'], 'c');
  day(pair);
  vote(pair, 'b');
  check(
    pair.winner == 'lovers' &&
        (pair.publicState['winner_ids'] as List).toSet().containsAll([
          'w',
          'a',
        ]),
    'Mixed couple victory',
  );

  final guard = NightGame({
    'g': 'guardian',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  });
  guard.startNight();
  rejects(() => guard.callNight('wolves'));
  guard.callNight('guardian');
  act(guard, 'g', 'guardian.protect', targets: ['a']);
  check(
    guard.privateState('g')['guardian_protected_id'] == 'a',
    'Guardian aura missing',
  );
  check(
    guard.privateState('a')['guardian_protected_id'] == 'a',
    'Protected player aura missing',
  );
  check(
    !guard.privateState('w').containsKey('guardian_protected_id') &&
        !guard.privateState('b').containsKey('guardian_protected_id') &&
        !guard.publicState.containsKey('guardian_protected_id'),
    'Protection leaked',
  );
  close(guard);
  wolves(guard, ['w'], 'a');
  check(guard.hostState['victim'] == null, 'Guarded victim remains exposed');
  day(guard);
  check(guard.deaths.isEmpty, 'Protection failed');
  vote(guard, null);
  guard.startNight();
  guard.callNight('guardian');
  rejects(() => act(guard, 'g', 'guardian.protect', targets: ['a']));
  act(guard, 'g', 'guardian.protect', targets: ['g']);
  close(guard);
  wolves(guard, ['w'], 'b');
  dawn(guard);
  check(
    guard.deaths.contains('b') && guard.alive.contains('g'),
    'Guardian targeting',
  );

  final elder = NightGame({
    'e': 'elder',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  });
  elder.startNight();
  wolves(elder, ['w'], 'e');
  day(elder);
  check(elder.alive.contains('e'), 'Elder first resistance');
  vote(elder, null);
  elder.startNight();
  wolves(elder, ['w'], 'e');
  dawn(elder);
  check(
    !elder.alive.contains('e') &&
        elder.publicState['village_powers_lost'] == false,
    'Elder resistance consumed once',
  );
  final punishment = NightGame({
    'e': 'elder',
    'w': 'werewolf',
    's': 'seer',
    't': 'witch',
    'h': 'hunter',
    'p': 'piper',
    'a': 'villager',
  });
  punishment.startNight();
  wolves(punishment, ['w'], 'h');
  punishment.callNight('witch');
  act(punishment, 't', 'witch.potions', kill: 'e');
  close(punishment);
  dawn(punishment);
  check(
    punishment.publicState['village_powers_lost'] == true &&
        punishment.hostState['pending_hunter'] == null,
    'Elder sanctions before hunter',
  );
  close(punishment);
  vote(punishment, null);
  punishment.startNight();
  check(
    !punishment.nightActions.any((a) => a['action'] == 'seer') &&
        punishment.nightActions.any((a) => a['action'] == 'piper'),
    'Village powers and solitary separation',
  );

  final goat = NightGame({
    'g': 'scapegoat',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
    'd': 'villager',
  });
  goat.startNight();
  day(goat);
  goat.startVote();
  act(goat, 'a', 'vote.cast', target: 'b');
  act(goat, 'b', 'vote.cast', target: 'a');
  close(goat);
  check(
    goat.phase == 'scapegoat' && !goat.alive.contains('g'),
    'Scapegoat tie',
  );
  act(goat, 'g', 'scapegoat.voters', targets: ['a', 'b']);
  close(goat);
  goat.startNight();
  day(goat);
  goat.startVote();
  check(goat.publicState['vote_eligible_count'] == 2, 'Restricted electorate');
  rejects(() => act(goat, 'w', 'vote.cast', target: 'a'));
  act(goat, 'a', 'vote.cast', target: 'w');
  act(goat, 'b', 'vote.cast');
  close(goat);
  check(
    (goat.publicState['vote_result'] as Map)['abstentions'] == 0,
    'Vote counting with restrictions',
  );

  final alpha = NightGame({
    'x': 'alpha_wolf',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
    'd': 'villager',
    'e': 'villager',
  });
  alpha.startNight();
  wolves(alpha, ['x', 'w'], 'a');
  alpha.callNight('alpha');
  rejects(() => act(alpha, 'x', 'alpha.choose', targets: ['a']));
  act(alpha, 'x', 'alpha.choose', targets: ['b']);
  close(alpha);
  day(alpha);
  check(alpha.deaths.toSet().containsAll(['a', 'b']), 'Second wolf victim');
  vote(alpha, 'w');
  alpha.startNight();
  check(
    !alpha.nightActions.any((a) => a['action'] == 'alpha'),
    'Alpha stops after a wolf death',
  );

  final white = NightGame({
    'q': 'white_wolf',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  });
  white.startNight();
  check(
    !white.nightActions.any((a) => a['action'] == 'white_wolf'),
    'White wolf odd night',
  );
  day(white);
  vote(white, null);
  white.startNight();
  white.callNight('white_wolf');
  act(white, 'q', 'white_wolf.choose', targets: ['w']);
  close(white);
  day(white);
  check(
    !white.alive.contains('w') && white.winner == null,
    'White wolf attack / village victory',
  );
  final alone = NightGame({'q': 'white_wolf', 'a': 'villager'});
  alone.startNight();
  wolves(alone, ['q'], 'a');
  dawn(alone);
  close(alone);
  check(alone.winner == 'white_wolf', 'White wolf solo victory');

  final infection = NightGame({
    'f': 'wolf_father',
    'w': 'werewolf',
    's': 'seer',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
    'd': 'villager',
  });
  infection.startNight();
  wolves(infection, ['f', 'w'], 's');
  infection.callNight('infection');
  act(infection, 'f', 'infection.convert', targets: ['s']);
  close(infection);
  day(infection);
  check(
    infection.alive.contains('s') &&
        infection.privateState('s')['is_pack'] == false,
    'Delayed infection',
  );
  vote(infection, null);
  infection.startNight();
  check(
    infection.roles['s'] == 'seer' &&
        infection.privateState('s')['is_pack'] == true &&
        infection.privateState('s')['camp'] == 'wolves',
    'Infected role keeps power and changes camp',
  );
  check(
    !infection.publicState.containsKey('pending_infections'),
    'Infection secret',
  );
  final saved = NightGame({
    'f': 'wolf_father',
    't': 'witch',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  });
  saved.startNight();
  wolves(saved, ['f'], 'a');
  saved.callNight('infection');
  act(saved, 'f', 'infection.convert', targets: ['a']);
  close(saved);
  saved.callNight('witch');
  act(saved, 't', 'witch.potions', save: true);
  close(saved);
  day(saved);
  vote(saved, null);
  saved.startNight();
  check(
    saved.privateState('a')['is_pack'] == false &&
        !saved.nightActions.any((a) => a['action'] == 'infection'),
    'Life potion cancels infection without restoring charge',
  );

  final idiot = NightGame({
    'i': 'idiot',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  }, revealOnDeath: false);
  idiot.startNight();
  day(idiot);
  vote(idiot, 'i');
  final summary = idiot.publicState['vote_result'] as Map;
  check(
    idiot.alive.contains('i') &&
        summary['reason'] == 'idiot_grace' &&
        summary['eligible'] == 5 &&
        summary['abstentions'] == 0,
    'Idiot grace / electorate',
  );
  check(
    (idiot.publicState['revealed_roles'] as Map)['i'] == 'idiot',
    'Idiot publicly revealed',
  );
  idiot.startNight();
  day(idiot);
  idiot.startVote();
  rejects(() => act(idiot, 'i', 'vote.cast', target: 'w'));

  final piper = NightGame({
    'p': 'piper',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  });
  piper.startNight();
  piper.callNight('piper');
  rejects(() => act(piper, 'p', 'piper.charm', targets: ['p', 'a']));
  act(piper, 'p', 'piper.charm', targets: ['a', 'b']);
  check(
    piper.privateState('a')['charmed'] == true &&
        !piper.privateState('c').containsKey('charmed_ids'),
    'Charm privacy',
  );
  close(piper);
  wolves(piper, ['w'], 'c');
  day(piper);
  vote(piper, null);
  piper.startNight();
  piper.callNight('piper');
  act(piper, 'p', 'piper.charm', targets: ['w']);
  check(
    piper.winner == 'piper' && piper.phase == 'ended',
    'Piper immediate victory',
  );

  final angel = NightGame({
    'n': 'angel',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  });
  angel.startNight();
  day(angel);
  vote(angel, 'n');
  check(angel.winner == 'angel', 'Angel first vote');
  final fallback = NightGame({
    'n': 'angel',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  });
  fallback.startNight();
  day(fallback);
  vote(fallback, null);
  check(fallback.roles['n'] == 'villager', 'Angel fallback');

  final girl = NightGame({
    'g': 'little_girl',
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  }, chanceDraw: (_) => 0);
  girl.startNight();
  girl.callNight('wolves');
  act(girl, 'w', 'wolves.chat', text: 'Visez la maison au nord.');
  act(girl, 'g', 'little_girl.peek', targets: []);
  check(
    girl.privateState('g')['peek_message'] == 'Visez la maison au nord.',
    'Anonymous whisper',
  );
  check(
    (girl.privateState('w')['spotted_girls'] as List).contains('g'),
    'Spotted girl',
  );
  check(
    !girl.privateState('a').containsKey('peek_message') &&
        !girl.publicState.containsKey('spotted_girls'),
    'Peek privacy',
  );
  rejects(() => act(girl, 'g', 'little_girl.peek', targets: []));
  print(
    'All 12 additional roles OK: actions, secrets, reactions, votes, infection and solo victories.',
  );
}
