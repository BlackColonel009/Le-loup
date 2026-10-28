import 'dart:async';
import '../lib/local_host.dart';

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline))
      throw StateError('Narration snapshot timeout');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> main() async {
  final host = LocalHost();
  final clients = <LobbyClient>[];
  final subscriptions = <StreamSubscription>[];
  final snapshots = <int, Map>{};
  try {
    await host.start(port: 0);
    for (var index = 0; index < 4; index++) {
      final client = LobbyClient(), i = index;
      clients.add(client);
      subscriptions.add(
        client.events.listen((e) {
          if (e['type'] == 'room.snapshot') snapshots[i] = e;
        }),
      );
      await client.connect('127.0.0.1:${host.port}', host.code, 'Voix $index');
    }
    host.setNarration(profile: 'old_wizard', automatic: true);
    await until(
      () =>
          snapshots.length == 4 &&
          snapshots.values.every((s) => s['narration_profile'] == 'old_wizard'),
    );
    for (final client in clients) client.setReady(true);
    await until(() => host.launchError == null);
    host.startGame();
    host.startNight();
    host.callNight('wolves');
    host.advanceNight();
    await until(
      () => snapshots.values.every(
        (s) =>
            (s['game']?['narration_events'] as List? ?? [])
                .lastOrNull?['cue'] ==
            'mdj_close_wolves.wav',
      ),
    );
    host.setNarration(profile: 'duke', automatic: false);
    await until(
      () => snapshots.values.every(
        (s) =>
            s['narration_profile'] == 'duke' &&
            s['automatic_narration'] == false,
      ),
    );
    if (snapshots.values.any(
      (s) => s.containsKey('game_host') || s.containsKey('assignments'),
    )) {
      throw StateError('A public narration snapshot exposed private data');
    }
    print(
      'Narration réseau OK : profil commun à quatre joueurs, rendormissement, désactivation en partie et secrets préservés.',
    );
  } finally {
    for (final client in clients) await client.dispose();
    for (final sub in subscriptions) await sub.cancel();
    await host.dispose();
  }
}
