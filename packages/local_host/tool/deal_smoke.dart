import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../lib/local_host.dart';

void check(bool valid, String message) {
  if (!valid) throw StateError(message);
}

class Peer {
  Peer(this.socket) : stream = StreamIterator(socket.asBroadcastStream());
  final WebSocket socket;
  final StreamIterator<dynamic> stream;
  void send(Map<String, dynamic> data) =>
      socket.add(jsonEncode({'version': 1, ...data}));
  Future<Map<String, dynamic>> next(String type) async {
    while (await stream.moveNext().timeout(const Duration(seconds: 3))) {
      final event =
          jsonDecode(stream.current as String) as Map<String, dynamic>;
      if (event['type'] == 'room.snapshot') {
        check(!event.containsKey('assignments'), 'Fuite des attributions');
        check(!jsonEncode(event).contains('token'), 'Fuite de jeton');
        check(
          (event['players'] as List).every((p) => !p.containsKey('role')),
          'Fuite de rôle public',
        );
      }
      if (event['type'] == type) return event;
    }
    throw StateError('Événement attendu : $type');
  }

  Future<void> close() async {
    await socket.close();
    await stream.cancel();
  }
}

Future<void> main() async {
  final host = LocalHost();
  final peers = <Peer>[];
  Future<Peer> open() async {
    final peer = Peer(
      await WebSocket.connect('ws://127.0.0.1:${host.port}/ws'),
    );
    peers.add(peer);
    return peer;
  }

  try {
    await host.start(port: 0);
    var refused = false;
    try {
      host.startGame();
    } on StateError {
      refused = true;
    }
    check(refused, 'Lancement vide accepté');
    final sessions = <Map<String, dynamic>>[];
    for (var i = 0; i < 4; i++) {
      final peer = await open();
      peer.send({
        'type': 'room.join',
        'code': host.code,
        'nickname': 'Joueur $i',
      });
      sessions.add(await peer.next('room.joined'));
      await peer.next('room.snapshot');
      peer.send({'type': 'player.ready', 'ready': true});
      await peer.next('room.snapshot');
    }
    // Toute modification doit invalider les confirmations précédentes.
    host.configure({
      'villager': 0,
      'werewolf': 1,
      'seer': 1,
      'witch': 1,
      'hunter': 1,
    }, campOnly: true);
    check(
      (host.snapshot['players'] as List).every((p) => p['ready'] == false),
      'Prêts non invalidés',
    );
    for (final peer in peers) {
      peer.send({'type': 'player.ready', 'ready': true});
      // Les événements antérieurs sont conservés ; attendre l'état serveur ci-dessous.
    }
    for (var i = 0; i < 50 && host.launchError != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    check(host.launchError == null, 'Composition valide refusée');
    host.startGame();
    final roles = <String>[];
    for (var i = 0; i < 4; i++) {
      final event = await peers[i].next('game.role');
      roles.add(event['role'] as String);
      check(
        event['role'] ==
            (host.snapshot['assignments'] as Map)[sessions[i]['id']],
        'Mauvaise carte privée',
      );
      check(event['seer_camp_only'] == true, 'Variante oubliée');
    }
    check(
      roles.toSet().length == 4 && !roles.contains('villager'),
      'Distribution incorrecte',
    );
    refused = false;
    try {
      host.startGame();
    } on StateError {
      refused = true;
    }
    check(refused, 'Redistribution acceptée');
    final original = peers.first;
    await original.close();
    for (
      var i = 0;
      i < 50 && (host.snapshot['players'] as List).first['connected'] == true;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    check(
      (host.snapshot['players'] as List).length == 4,
      'Place perdue après coupure',
    );
    final impostor = await open();
    impostor.send({
      'type': 'room.resume',
      'code': host.code,
      'token': 'incorrect',
    });
    await impostor.next('error');
    impostor.send({
      'type': 'room.join',
      'code': host.code,
      'nickname': 'Intrus',
    });
    await impostor.next('error');
    final resumed = await open();
    resumed.send({
      'type': 'room.resume',
      'code': host.code,
      'token': sessions.first['token'],
    });
    check(
      (await resumed.next('room.joined'))['id'] == sessions.first['id'],
      'Identité changée',
    );
    check(
      (await resumed.next('game.role'))['role'] == roles.first,
      'Rôle changé à la reprise',
    );
    resumed.send({'type': 'game.start'});
    await resumed.next('error');
    print(
      'Distribution OK : validation, composition, confirmations, confidentialité, unicité, reprise et permissions.',
    );
  } finally {
    for (final peer in peers) {
      await peer.close();
    }
    await host.dispose();
  }
}
