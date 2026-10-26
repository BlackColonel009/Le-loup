import 'dart:async';
import '../lib/local_host.dart';

Future<void> main() async {
  final host = LocalHost();
  final client = LobbyClient();
  final joined = Completer<void>();
  final ready = Completer<void>();
  final disconnected = Completer<void>();
  final subscription = client.events.listen((event) {
    if (event['type'] == 'room.snapshot') {
      if (!joined.isCompleted) joined.complete();
      if ((event['players'] as List).any((p) => p['ready'] == true)) {
        if (!ready.isCompleted) ready.complete();
      }
    }
    if (event['type'] == 'disconnected' && !disconnected.isCompleted) {
      disconnected.complete();
    }
  });
  try {
    await host.start(port: 0);
    await client.connect('127.0.0.1:${host.port}', host.code, 'Alice');
    await joined.future.timeout(const Duration(seconds: 3));
    if (client.id == null) throw StateError('Identifiant absent.');
    client.setReady(true);
    await ready.future.timeout(const Duration(seconds: 3));
    await host.stop();
    await disconnected.future.timeout(const Duration(seconds: 3));
    print('Client OK: connexion, identification, prêt, fermeture MDJ.');
  } finally {
    await subscription.cancel();
    await client.dispose();
    await host.dispose();
  }
}
