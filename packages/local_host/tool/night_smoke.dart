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
  bool save = false,
  String? kill,
  String? text,
}) => game.act(id, {
  'phase_revision': game.revision,
  'action': action,
  'target': target,
  'save': save,
  'kill': kill,
  'text': text,
});

void main() {
  var now = DateTime.utc(2026, 10, 26);
  final roles = {
    's': 'seer',
    'w': 'werewolf',
    't': 'witch',
    'h': 'hunter',
    'v': 'villager',
  };
  final game = NightGame(roles, clock: () => now);
  game.startNight(seconds: 60);
  nextClassic(game);
  check(game.phase == 'seer', 'Ordre des appels');
  rejects(() => act(game, 'v', 'seer.inspect', target: 'w'));
  act(game, 's', 'seer.inspect', target: 'w');
  check(
    (game.privateState('s')['vision'] as Map)['value'] == 'werewolf',
    'Vision exacte',
  );
  check(!game.privateState('v').containsKey('vision'), 'Fuite de vision');
  rejects(() => act(game, 's', 'seer.inspect', target: 'v'));
  nextClassic(game);
  act(game, 'w', 'wolves.chat', text: 'Ciblons le Chasseur');
  check(
    (game.privateState('w')['messages'] as List).length == 1,
    'Chat de meute',
  );
  check(!game.privateState('v').containsKey('messages'), 'Fuite du chat');
  act(game, 'w', 'wolves.choose', target: 'h');
  nextClassic(game);
  check(game.privateState('t')['victim'] == 'h', 'Information Sorcière');
  act(game, 't', 'witch.potions', kill: 'w');
  nextClassic(game);
  check(
    !game.alive.contains('h') && !game.alive.contains('w'),
    'Décès nocturnes',
  );
  check(game.winner == null, 'Victoire vérifiée avant le Chasseur');
  nextClassic(game);
  check(
    game.phase == 'hunter' && game.privateState('h')['can_act'] == true,
    'Tir réactif absent',
  );
  act(game, 'h', 'hunter.shoot', target: 't');
  nextClassic(game);
  check(
    game.winner == 'village' && game.phase == 'ended',
    'Victoire après réactions',
  );

  final potions = NightGame(roles, clock: () => now);
  potions.startNight();
  nextClassic(potions);
  nextClassic(potions);
  act(potions, 'w', 'wolves.choose', target: 't');
  nextClassic(potions);
  act(potions, 't', 'witch.potions', save: true, kill: 'v');
  nextClassic(potions);
  check(
    potions.alive.contains('t') && !potions.alive.contains('v'),
    'Double potion et auto-sauvetage',
  );
  nextClassic(potions);
  potions.startVote();
  nextClassic(potions);
  potions.startNight();
  nextClassic(potions);
  nextClassic(potions);
  act(potions, 'w', 'wolves.choose', target: 's');
  nextClassic(potions);
  check(
    !potions.privateState('t').containsKey('victim'),
    'Victime révélée sans potion de vie',
  );
  rejects(() => act(potions, 't', 'witch.potions', save: true));
  rejects(() => act(potions, 't', 'witch.potions', kill: 's'));

  final agreement = NightGame({
    'a': 'werewolf',
    'b': 'werewolf',
    'c': 'villager',
    'd': 'villager',
    'e': 'villager',
  }, clock: () => now);
  agreement.startNight(seconds: 15);
  nextClassic(agreement);
  act(agreement, 'a', 'wolves.choose', target: 'c');
  act(agreement, 'b', 'wolves.choose', target: 'd');
  agreement.pause();
  now = now.add(const Duration(seconds: 60));
  check(agreement.remainingMilliseconds == 15000, 'Pause non respectée');
  rejects(() => act(agreement, 'a', 'wolves.choose', target: 'd'));
  agreement.resume();
  now = now.add(const Duration(seconds: 16));
  check(agreement.expire(), 'Échéance ignorée');
  rejects(() => act(agreement, 'a', 'wolves.choose', target: 'd'));
  nextClassic(agreement);
  check(agreement.deaths.isEmpty, 'Désaccord de meute ignoré');

  final camp = NightGame(roles, campOnly: true);
  camp.startNight();
  nextClassic(camp);
  act(camp, 's', 'seer.inspect', target: 'w');
  check(
    (camp.privateState('s')['vision'] as Map)['value'] == 'wolves',
    'Variante camp',
  );
  rejects(
    () => camp.act('s', {
      'phase_revision': -1,
      'action': 'seer.inspect',
      'target': 't',
    }),
  );
  final draw = NightGame({'h': 'hunter', 'w': 'werewolf'});
  draw.startNight();
  nextClassic(draw);
  act(draw, 'w', 'wolves.choose', target: 'h');
  nextClassic(draw);
  nextClassic(draw);
  act(draw, 'h', 'hunter.shoot', target: 'w');
  nextClassic(draw);
  check(draw.winner == 'draw', 'Partie nulle après le dernier tir');
  print(
    'Nuit OK : permissions, secrets, délais, pause, unanimité, potions, Chasseur et victoire.',
  );
}
