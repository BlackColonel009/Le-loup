import 'classic_scenario_driver.dart';
import '../lib/src/night_game.dart';
import '../lib/src/village_weather.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  var now = DateTime.utc(2026, 10, 26);
  final rolls = [0, 30, 80];
  final roles = {
    'w': 'werewolf',
    'a': 'villager',
    'b': 'villager',
    'c': 'villager',
  };
  final game = NightGame(
    roles,
    clock: () => now,
    weatherDraw: (limit) => limit == 100 ? rolls.removeAt(0) : 7,
  );
  for (final expected in ['storm', 'rain', 'clear']) {
    game.startNight();
    final start = VillageWeather.fromMap(game.publicState['weather'] as Map);
    check(
      start.kind == expected && !start.rainbow,
      'Choix nocturne public incorrect',
    );
    now = now.add(const Duration(seconds: 10));
    final again = VillageWeather.fromMap(game.publicState['weather'] as Map);
    check(
      again.kind == expected &&
          again.seed == start.seed &&
          again.elapsedMs == 10000,
      'La météo a changé entre deux instantanés',
    );
    nextClassic(game); // Loups, aucune victime.
    check(
      (game.publicState['weather'] as Map)['kind'] == expected,
      'Météo liée au rôle actif',
    );
    nextClassic(game); // Aube.
    final dawn = VillageWeather.fromMap(game.publicState['weather'] as Map);
    check(
      dawn.kind == 'clear' && dawn.rainbow == (expected != 'clear'),
      'Arc-en-ciel incorrect après la pluie',
    );
    nextClassic(game); // Débat.
    check(
      game.alive.length == 4 && game.winner == null,
      'La météo a changé les règles',
    );
    game.startVote();
    nextClassic(game); // Abstention, aucune mort.
    check(
      (game.publicState['weather'] as Map)['rainbow'] == (expected != 'clear'),
      'La lueur ne dure pas toute la journée',
    );
  }
  const storm = VillageWeather(kind: 'storm', seed: 7);
  final flash = storm.flashAt(0);
  check(storm.lightningAt(flash + 400) > 0, 'Éclair manquant');
  check(storm.thunderAt(flash + 700) == 0, 'Grondement manquant');
  check(
    storm.thunderAt(flash + 2000) == null,
    'Un orage a été rejoué trop tard',
  );
  check(
    const VillageWeather().lightningAt(4400) == 0,
    'Éclair par temps clair',
  );
  check(
    VillageWeather.fromMap(null).kind == 'clear',
    'Ancien salon incompatible',
  );
  print(
    'Météo : nuits partagées, aube après pluie, règles intactes et timeline vérifiées.',
  );
}
