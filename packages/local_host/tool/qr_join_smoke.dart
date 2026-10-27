import 'dart:async';
import '../lib/local_host.dart';

Future<void> main() async {
  final host = LocalHost();
  final clients = [LobbyClient(), LobbyClient()];
  final subscriptions = <StreamSubscription>[];
  var disconnected = false;
  Future<void> until(bool Function() ready) async {
    for (var i = 0; i < 100 && !ready(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (!ready()) throw StateError('Connexion par invitation non reçue.');
  }

  try {
    await host.start(port: 0);
    final invitation = LocalInvitation.parse(
      LocalInvitation(
        address: '127.0.0.1:${host.port}',
        code: host.code,
      ).payload,
    );
    for (var i = 0; i < clients.length; i++) {
      subscriptions.add(
        clients[i].events.listen((event) {
          if (event['type'] == 'disconnected' || event['type'] == 'error')
            disconnected = true;
        }),
      );
      await clients[i].connect(
        invitation.address,
        invitation.code,
        'Joueur QR $i',
      );
      await until(() => clients[i].id != null);
      clients[i].setReady(true);
    }
    await until(
      () =>
          (host.snapshot['players'] as List).length == 2 &&
          (host.snapshot['players'] as List).every(
            (player) => player['ready'] == true,
          ),
    );
    if (clients[0].id == clients[1].id || disconnected)
      throw StateError('Identités QR mélangées.');
    print(
      'Invitation QR : adresse et code transmis ; deux joueurs distincts, prêts et connectés.',
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
