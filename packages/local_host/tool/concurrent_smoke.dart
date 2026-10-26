import 'dart:async';
import '../lib/local_host.dart';

Future<void> main() async {
  // Cycle raccourci pour couvrir plusieurs pings sans attendre plusieurs minutes.
  final host = LocalHost(heartbeatInterval: const Duration(seconds: 2));
  final clients = List.generate(4, (_) => LobbyClient());
  final subscriptions = <StreamSubscription<Map<String, dynamic>>>[];
  final failures = <String>[];
  final counts = <int, int>{};
  try {
    await host.start(port: 0);
    for (var i = 0; i < clients.length; i++) {
      final index = i;
      subscriptions.add(
        clients[i].events.listen((event) {
          if (event['type'] == 'disconnected' || event['type'] == 'error') {
            failures.add('Joueur $index : ${event['message']}');
          }
          if (event['type'] == 'room.snapshot')
            counts[index] = (event['players'] as List).length;
        }),
      );
    }
    await Future.wait([
      for (var i = 0; i < clients.length; i++)
        clients[i].connect('127.0.0.1:${host.port}', host.code, 'Joueur $i'),
    ]);
    // Dépasser plusieurs cycles de contrôle de présence, pas seulement la connexion.
    for (var i = 0; i < 27; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      for (final client in clients) {
        if (client.id != null) client.setReady(i.isEven);
      }
    }
    if (failures.isNotEmpty ||
        counts.length != 4 ||
        counts.values.any((n) => n != 4)) {
      throw StateError(
        'Connexions concurrentes : $failures ; participants : $counts',
      );
    }
    print(
      'Concurrence OK : 4 joueurs simultanés, 27 secondes et contrôles de présence.',
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
