import '../lib/src/night_game.dart';

void check(bool value, String reason) {
  if (!value) throw StateError(reason);
}

void rejects(void Function() f) {
  var denied = false;
  try {
    f();
  } on StateError {
    denied = true;
  } on ArgumentError {
    denied = true;
  }
  check(denied, 'Forbidden action accepted');
}

void act(
  NightGame g,
  String id,
  String command, {
  String? target,
  List<String>? targets,
  bool? save,
  String? kill,
}) => g.act(id, {
  'action': command,
  'phase_revision': g.revision,
  if (target != null) 'target': target,
  'targets': targets ?? [],
  if (save != null) 'save': save,
  if (kill != null) 'kill': kill,
});
NightGame game(
  String edition, {
  Map<String, String> extra = const {},
  int Function(int)? draw,
  bool revealOnDeath = true,
}) => NightGame(
  {
    's': 'sulfuron',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
    'd': 'villager',
    'e': 'villager',
    'f': 'villager',
    'w': 'werewolf',
    ...extra,
  },
  editions: {'s': edition},
  chanceDraw: draw ?? (_) => 0,
  revealOnDeath: revealOnDeath,
);
void day(NightGame g) {
  g.finishNight();
  check(g.phase == 'dawn', 'Dawn expected');
  g.advance();
  check(g.phase == 'day', 'Day expected');
}

void vote(NightGame g, String? target) {
  g.startVote();
  for (final id in g.alive.toList()) {
    if (g.privateState(id)['can_vote'] == true)
      act(g, id, 'vote.cast', target: target);
  }
  g.advance();
}

String reveal(NightGame g) {
  g.callNight('sulfuron');
  act(g, 's', 'sulfuron.reveal');
  g.advance();
  return ((g.publicState['sulfuron_events'] as List).last as Map)['player']
      as String;
}

int lives(NightGame g) => g.privateState('s')['sulfuron_lives'] as int;
void gain(NightGame g) {
  g.startNight();
  final target = reveal(g);
  day(g);
  vote(g, target);
  check(lives(g) > 0, 'Life not awarded');
}

void hunt(NightGame g, String target) {
  g.callNight('wolves');
  act(g, 'w', 'wolves.choose', target: target);
  g.advance();
}

void main() {
  final bluff = game('classic', draw: (max) => max - 1);
  bluff.startNight();
  bluff.callNight('sulfuron');
  rejects(() => act(bluff, 's', 'sulfuron.bluff', targets: ['s']));
  act(bluff, 's', 'sulfuron.bluff', targets: ['a']);
  final e = (bluff.publicState['sulfuron_events'] as List).last as Map;
  check(
    e['role'] != 'villager' &&
        !e.containsKey('actor') &&
        !e.containsKey('true_role'),
    'Bluff leakage or true role',
  );
  check(
    bluff.roles['a'] == 'villager' &&
        !(bluff.publicState['revealed_roles'] as Map).containsKey('a'),
    'Bluff changed actual identity',
  );
  rejects(() => act(bluff, 's', 'sulfuron.reveal'));
  bluff.advance();
  day(bluff);
  vote(bluff, null);
  bluff.startNight();
  bluff.callNight('sulfuron');
  rejects(() => act(bluff, 's', 'sulfuron.bluff', targets: ['a']));
  bluff.advance();
  day(bluff);
  vote(bluff, null);
  bluff.startNight();
  bluff.callNight('sulfuron');
  act(bluff, 's', 'sulfuron.bluff', targets: ['a']);

  final classic = game('classic');
  gain(classic);
  check(
    (classic.publicState['death_events'] as List).last['effect'] ==
        'sulfuron_fire',
    'Missing fire effect',
  );
  check(
    !classic.privateState('w').containsKey('sulfuron_lives'),
    'Private charge leaked',
  );
  check(
    (classic.privateState('s')['sulfuron_events'] as List).last['kind'] ==
        'soul_gained',
    'Missing private vote gain ceremony',
  );

  final hunted = game('classic', revealOnDeath: false);
  hunted.startNight();
  final huntedTarget = reveal(hunted);
  hunt(hunted, huntedTarget);
  day(hunted);
  final wolfDeath = (hunted.publicState['death_events'] as List).single as Map;
  check(
    wolfDeath['cause'] == 'night' &&
        wolfDeath['effect'] == 'sulfuron_fire' &&
        wolfDeath['sulfuron_card']['role'] == 'villager' &&
        !wolfDeath.containsKey('role') &&
        lives(hunted) == 1,
    'Wolf kill must keep its cause and grant a single burn and life',
  );
  check(
    (hunted.privateState('s')['sulfuron_events'] as List).single['kind'] ==
            'soul_gained' &&
        !(hunted.publicState['sulfuron_events'] as List).any(
          (event) => event['kind'] == 'soul_gained',
        ),
    'Life gain must be private',
  );
  vote(hunted, 'b');
  check(lives(hunted) == 1, 'A later vote must not grant the same soul twice');

  classic.startNight();
  hunt(classic, 's');
  day(classic);
  check(
    classic.alive.contains('s') && lives(classic) == 0,
    'Pack resurrection failed',
  );
  check(
    !(classic.publicState['death_events'] as List).any(
      (e) => e['player'] == 's',
    ),
    'False death statistic',
  );

  final voted = game('classic');
  gain(voted);
  voted.startNight();
  day(voted);
  vote(voted, 's');
  check(!voted.alive.contains('s'), 'Classic immune to vote');

  for (final edition in ['intense', 'horror']) {
    final g = game(edition);
    gain(g);
    gain(g);
    check(lives(g) == 2, 'Charges do not accumulate');
    g.startNight();
    day(g);
    vote(g, 's');
    check(
      g.alive.contains('s') &&
          lives(g) == 1 &&
          g.privateState('s')['sulfuron_vote_used'] == true,
      'First vote protection',
    );
    if (edition == 'horror') {
      rejects(() => act(g, 's', 'sulfuron.mark', targets: ['s']));
      act(g, 's', 'sulfuron.mark', targets: ['w']);
      g.startNight();
      g.callNight('sulfuron');
      final revenge = (g.publicState['sulfuron_events'] as List).last as Map;
      check(
        revenge['power'] == 'revenge' &&
            revenge['player'] == 'w' &&
            revenge['role'] == 'werewolf',
        'Wrong revenge',
      );
      act(g, 's', 'night.pass');
      g.advance();
    } else {
      g.startNight();
    }
    day(g);
    vote(g, 's');
    check(
      !g.alive.contains('s'),
      'Second vote must be final despite remaining charge',
    );
  }

  final expired = game('classic');
  expired.startNight();
  final target = reveal(expired);
  day(expired);
  vote(expired, null);
  expired.startNight();
  day(expired);
  vote(expired, target);
  check(lives(expired) == 0, 'Expired stake awarded life');

  final poison = game('horror', extra: {'t': 'witch'});
  gain(poison);
  poison.startNight();
  hunt(poison, 's');
  poison.callNight('witch');
  act(poison, 't', 'witch.potions', save: false, kill: 's');
  poison.advance();
  day(poison);
  check(
    !poison.alive.contains('s') && lives(poison) == 1,
    'Poison must bypass souls, including when attacked by pack',
  );

  final win = game('classic', draw: (max) => max - 1);
  gain(win);
  check(
    win.winner == 'sulfuron' &&
        (win.publicState['winner_ids'] as List).single == 's' &&
        (win.publicState['death_events'] as List).last['effect'] ==
            'sulfuron_fire',
    'Sulfuron must win alone ahead of Village',
  );
  final hunter = game('classic', extra: {'h': 'hunter'});
  hunter.startNight();
  day(hunter);
  vote(hunter, 'h');
  check(
    hunter.phase == 'hunter' && hunter.winner == null,
    'Victory before hunter reaction',
  );
  act(hunter, 'h', 'hunter.shoot', target: 's');
  hunter.advance();
  check(
    !hunter.alive.contains('s') && hunter.winner == null,
    'Hunter reaction did not eliminate Sulfuron',
  );

  final neutral = game('classic', extra: {'p': 'piper'});
  neutral.startNight();
  day(neutral);
  vote(neutral, 'w');
  check(neutral.winner == null, 'Other solitary ignored in win condition');
  final truthful = game('classic');
  truthful.startNight();
  truthful.callNight('sulfuron');
  act(truthful, 's', 'sulfuron.bluff', targets: ['a']);
  check(
    (truthful.publicState['sulfuron_events'] as List).last['role'] ==
        'villager',
    'Rare truthful announcement missing',
  );
  truthful.advance();
  day(truthful);
  vote(truthful, 'a');
  check(
    lives(truthful) == 0 &&
        (truthful.publicState['death_events'] as List).last['effect'] == null,
    'A truthful bluff must not grant a soul or burn',
  );

  final graced = NightGame({
    's': 'sulfuron',
    'a': 'idiot',
    'b': 'villager',
    'c': 'villager',
    'd': 'villager',
    'w': 'werewolf',
  }, chanceDraw: (_) => 0);
  graced.startNight();
  reveal(graced);
  day(graced);
  vote(graced, 'a');
  check(
    graced.alive.contains('a') && lives(graced) == 0,
    'Idiot grace must not grant a soul',
  );

  final swap = NightGame(
    {
      's': 'sulfuron',
      'a': 'villager',
      'b': 'villager',
      'c': 'villager',
      'd': 'villager',
      'w': 'werewolf',
      'm': 'metamorph',
    },
    editions: {'m': 'horror'},
    chanceDraw: (_) => 0,
  );
  swap.startNight();
  swap.callNight('metamorph');
  act(swap, 'm', 'night.pass');
  swap.advance();
  final marked = reveal(swap);
  day(swap);
  vote(swap, marked);
  swap.startNight();
  swap.callNight('metamorph');
  act(swap, 'm', 'metamorph.swap', targets: ['s', 'c']);
  swap.advance();
  check(
    swap.roles['c'] == 'sulfuron' &&
        swap.privateState('c')['sulfuron_lives'] == 1 &&
        !swap.privateState('s').containsKey('sulfuron_lives'),
    'Soul must follow exchanged card',
  );
  hunt(swap, 'c');
  day(swap);
  check(
    swap.alive.contains('c') && swap.privateState('c')['sulfuron_lives'] == 0,
    'Transferred soul cannot resurrect new owner',
  );
  print(
    'Sulfuron: bluff, cooldown, secrecy, fire, souls, poison, first/second vote, horror revenge and victory verified.',
  );
}
