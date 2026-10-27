import '../lib/src/night_game.dart';

/// Existing scenario fixtures explicitly choose the historical order. The game
/// itself never chooses the next nocturnal actor on behalf of the host.
void nextClassic(dynamic driver) {
  final engine = driver is NightGame;
  Map state() =>
      engine ? driver.publicState as Map : driver.snapshot['game'] as Map;
  List actions() => engine
      ? driver.nightActions as List
      : driver.snapshot['game_host']['night_actions'] as List? ?? [];
  void advance() {
    if (engine) {
      driver.advance();
    } else {
      driver.advanceNight();
    }
  }

  void call(String action) => driver.callNight(action);
  final phase = state()['phase'];
  if (phase == 'sleep') {
    final available = actions().where((a) => a['available'] == true);
    if (available.isEmpty) {
      driver.finishNight();
    } else {
      call(available.first['action'] as String);
    }
  } else if (['seer', 'wolves', 'witch'].contains(phase)) {
    advance();
    final next = phase == 'seer'
        ? 'wolves'
        : phase == 'wolves'
        ? 'witch'
        : null;
    if (next != null &&
        actions().any((a) => a['action'] == next && a['available'] == true)) {
      call(next);
    } else {
      driver.finishNight();
    }
  } else {
    advance();
  }
}
