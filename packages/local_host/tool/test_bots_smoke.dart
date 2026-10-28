import 'dart:async';
import '../lib/local_host.dart';

Future<void> until(bool Function() predicate) async {
  final end = DateTime.now().add(const Duration(seconds: 8));
  while (!predicate()) {
    if (DateTime.now().isAfter(end)) throw StateError('Simulation trop lente.');
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}

Future<void> main() async {
  final host = LocalHost();
  final table = TestBotTable(host)..delay = const Duration(milliseconds: 120);
  try {
    await host.start(port: 0, bindAddress: '127.0.0.1');
    await table.add(4);
    await until(
      () => (host.snapshot['players'] as List).every((p) => p['ready'] == true),
    );
    if (table.count != 4 || host.snapshot['test_mode'] != true)
      throw StateError('Bots absents.');
    if ((host.snapshot['players'] as List).any((p) => p['is_bot'] != true))
      throw StateError('Badge manquant.');
    table.paused = true;
    table.delay = const Duration(milliseconds: 2500);
    host.configure({
      ...host.deck,
      'werewolf': 1,
      'seer': 1,
      'villager': 2,
    }, campOnly: false);
    if ((host.snapshot['players'] as List).any((p) => p['ready'] != true)) {
      throw StateError(
        'Les bots doivent rester prêts, même en pause et en mode lent.',
      );
    }
    table.paused = false;
    table.delay = const Duration(milliseconds: 120);
    await until(
      () => (host.snapshot['players'] as List).every((p) => p['ready'] == true),
    );
    host.startGame();
    host.startNight();
    table.paused = true;
    host.callNight('seer');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if ((host.snapshot['game_host']['visions'] as Map).isNotEmpty)
      throw StateError('Pause ignorée.');
    table.paused = false;
    await until(
      () => (host.snapshot['game_host']['visions'] as Map).isNotEmpty,
    );
    host.advanceNight();
    host.callNight('wolves');
    await until(
      () => (host.snapshot['game_host']['wolf_choices'] as Map).length == 1,
    );
    host.advanceNight();
    host.finishNight();
    host.advanceNight();
    host.startVote(seconds: 15);
    await until(() => host.snapshot['game']['election_votes_received'] == 3);
    host.advanceNight();
    host.startVote(seconds: 15);
    await until(() => host.snapshot['game']['votes_received'] == 3);
    host.advanceNight();
    if (host.snapshot['phase'] != 'ended') {
      host.startNight();
      if ((host.snapshot['game_host']['night_actions'] as List).any(
        (a) => a['action'] == 'seer',
      )) {
        host.callNight('seer');
        await until(
          () => (host.snapshot['game_host']['visions'] as Map).isNotEmpty,
        );
        host.advanceNight();
      }
      host.callNight('wolves');
      await until(
        () => (host.snapshot['game_host']['wolf_choices'] as Map).isNotEmpty,
      );
      host.advanceNight();
      host.finishNight();
      host.advanceNight();
    }
    if (host.snapshot['phase'] != 'ended')
      throw StateError('La partie ne se termine pas.');
    if ((host.snapshot['game']['history'] as List).isEmpty)
      throw StateError('Historique absent.');
    print(
      'Bots : connexion, préparation, pause, vision, meute, élection, vote, fin et historique OK.',
    );
  } finally {
    await table.dispose();
    await host.dispose();
  }
}
