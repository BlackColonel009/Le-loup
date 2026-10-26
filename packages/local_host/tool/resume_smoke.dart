import 'dart:async';
import '../lib/local_host.dart';

Future<void> main() async {
  final host = LocalHost();
  final clients = <LobbyClient>[];
  final subscriptions = <StreamSubscription<Map<String, dynamic>>>[];
  final roles = <int, String>{};
  final connections = <int, int>{};
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 150 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (!condition()) throw StateError('État de reprise attendu non reçu.');
  }

  try {
    await host.start(port: 0);
    for (var i = 0; i < 4; i++) {
      final index = i;
      final client = LobbyClient();
      clients.add(client);
      subscriptions.add(
        client.events.listen((event) {
          if (event['type'] == 'room.joined')
            connections[index] = (connections[index] ?? 0) + 1;
          if (event['type'] == 'game.role')
            roles[index] = event['role'] as String;
        }),
      );
      await client.connect('127.0.0.1:${host.port}', host.code, 'Joueur $i');
      await until(() => client.id != null);
      client.setReady(true);
    }
    await until(() => host.launchError == null);
    host.startGame();
    await until(() => roles.length == 4);
    final id = clients.first.id;
    final role = roles.remove(0);
    await clients.first.disconnect();
    await until(
      () => (host.snapshot['players'] as List).first['connected'] == false,
    );
    await clients.first.reconnect();
    await until(() => roles.containsKey(0));
    if (clients.first.id != id || roles[0] != role || connections[0] != 2) {
      throw StateError('La reprise a changé l’identité ou la carte.');
    }
    print('Reprise client OK : même session, même rôle, salon verrouillé.');
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
