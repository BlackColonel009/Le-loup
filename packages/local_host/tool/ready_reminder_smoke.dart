import 'dart:async';
import '../lib/local_host.dart';

Future<void> main() async {
  final host = LocalHost();
  final clients = <LobbyClient>[];
  final subscriptions = <StreamSubscription<Map<String, dynamic>>>[];
  final reminders = <int>[0, 0, 0, 0];
  Future<void> waitFor(bool Function() condition) async {
    for (var i = 0; i < 100; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('État attendu non reçu');
  }

  try {
    await host.start(port: 0);
    for (var i = 0; i < 4; i++) {
      final index = i;
      final client = LobbyClient();
      clients.add(client);
      subscriptions.add(
        client.events.listen((event) {
          if (event['type'] == 'room.ready_reminder') reminders[index]++;
        }),
      );
      await client.connect('127.0.0.1:${host.port}', host.code, 'Joueur $i');
      await waitFor(() => client.id != null);
    }
    host.configure({
      'werewolf': 1,
      'villager': 3,
      'seer': 0,
      'witch': 0,
      'hunter': 0,
    }, campOnly: true);
    clients[0].setReady(true);
    await waitFor(
      () => (host.snapshot['players'] as List).first['ready'] == true,
    );
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        host.startGame();
        throw Exception('Une partie avec joueurs non prêts a démarré');
      } on StateError {
        // Expected launch refusal, after the private reminders are delivered.
      }
      await waitFor(() => reminders.skip(1).every((n) => n == attempt));
      if (reminders[0] != 0 || host.started) {
        throw Exception(
          'Rappel envoyé à un joueur prêt ou lancement prématuré',
        );
      }
    }
    for (final client in clients) {
      client.setReady(true);
    }
    await waitFor(() => host.launchError == null);
    host.startGame();
    if (!host.started) throw Exception('Lancement valide refusé');
    print(
      'OK : rappels répétés aux seuls joueurs non prêts et lancement protégé.',
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
