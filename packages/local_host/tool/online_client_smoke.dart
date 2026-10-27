import 'dart:async';
import '../lib/local_host.dart';

Future<void> until(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw StateError('Online test timeout');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> main(List<String> args) async {
  final host = OnlineHost(
    args.isEmpty ? 'http://127.0.0.1:18765' : args.single,
  );
  final clients = <LobbyClient>[];
  final subscriptions = <StreamSubscription>[];
  final private = <int, Map<String, dynamic>>{};
  try {
    await host.start(nickname: 'Logan');
    final code = host.snapshot['code'] as String;
    await host.command('configure', {
      'deck': host.deck,
      'camp_only': false,
      'pack': 'intense',
    });
    await until(() => host.snapshot['visual_pack'] == 'intense');
    for (var i = 0; i < 4; i++) {
      final index = i;
      final client = LobbyClient();
      clients.add(client);
      subscriptions.add(
        client.events.listen((event) {
          if (event['type'] == 'game.private') private[index] = event;
          if (event['type'] == 'room.snapshot' &&
              event.containsKey('assignments')) {
            throw StateError('Private host data leaked');
          }
        }),
      );
      await client.connect(
        onlineSocketUri(host.base, code).toString(),
        code,
        'Player $i',
        appearance: 'female',
      );
      await until(() => client.id != null);
      client.setReady(true);
    }
    await until(() => host.snapshot['launch_error'] == null);
    await host.command('start');
    await until(() => private.length == 4);
    await host.command('night.start', {'seconds': 120});
    await host.command('night.call', {'call': 'wolves'});
    await host.reconnect();
    if (host.snapshot['phase'] != 'wolves')
      throw StateError('Host session not restored');
    await clients.first.reconnect();
    await until(() => clients.first.id != null);
    print(
      'Online Dart client OK: create, Intense, 4 players, private roles, commands and MDJ/player resume.',
    );
  } finally {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    for (final client in clients) {
      await client.dispose();
    }
    await host.dispose();
  }
}
