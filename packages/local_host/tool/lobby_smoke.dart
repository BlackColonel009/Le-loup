import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../lib/local_host.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final host = LocalHost();
  final sockets = <WebSocket>[];
  final streams = <StreamIterator<dynamic>>[];
  Future<(WebSocket, StreamIterator<dynamic>)> peer() async {
    final socket = await WebSocket.connect('ws://127.0.0.1:${host.port}/ws');
    final stream = StreamIterator<dynamic>(socket.asBroadcastStream());
    sockets.add(socket);
    streams.add(stream);
    return (socket, stream);
  }

  Future<Map<String, dynamic>> next(
    StreamIterator<dynamic> stream,
    String type,
  ) async {
    while (await stream.moveNext().timeout(const Duration(seconds: 3))) {
      final value =
          jsonDecode(stream.current as String) as Map<String, dynamic>;
      if (value['type'] == type) return value;
    }
    throw StateError('Événement attendu : $type');
  }

  void join(WebSocket socket, String name, [String? code]) => socket.add(
    jsonEncode({
      'version': 1,
      'type': 'room.join',
      'nickname': name,
      'code': code ?? host.code,
    }),
  );
  try {
    await host.start(port: 0, nickname: 'Meneur');
    final (one, first) = await peer();
    join(one, 'Alice', '000000');
    check(
      (await next(first, 'error'))['message'] == 'Code de salon incorrect.',
      'Code refusé',
    );
    join(one, 'Alice');
    final id = (await next(first, 'room.joined'))['id'] as String;
    check(
      ((await next(first, 'room.snapshot'))['players'] as List).length == 1,
      'Première arrivée',
    );
    final (two, second) = await peer();
    join(two, 'alice');
    await next(second, 'error');
    join(two, 'Bob');
    await next(second, 'room.joined');
    check(
      ((await next(second, 'room.snapshot'))['players'] as List).length == 2,
      'Deuxième arrivée',
    );
    two.add(jsonEncode({'version': 1, 'type': 'player.ready', 'ready': true}));
    final updated = await next(second, 'room.snapshot');
    check((updated['players'] as List).last['ready'] == true, 'Statut prêt');
    // Un joueur ne peut pas fermer les inscriptions en forgeant un événement.
    two.add(jsonEncode({'version': 1, 'type': 'room.lock', 'locked': true}));
    await next(second, 'error');
    check(!host.locked, 'Permissions MDJ');
    host.setLocked(true);
    final (three, third) = await peer();
    join(three, 'Charlie');
    check(
      (await next(third, 'error'))['message'] ==
          'Les inscriptions sont fermées.',
      'Salon fermé',
    );
    await host.kick(id);
    check((host.snapshot['players'] as List).length == 1, 'Retrait joueur');
    await two.close();
    for (
      var i = 0;
      i < 30 && (host.snapshot['players'] as List).isNotEmpty;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    check((host.snapshot['players'] as List).isEmpty, 'Départ joueur');
    print(
      'Lobby OK: code, pseudos, arrivées, prêt, permissions, fermeture, retrait, départ.',
    );
  } finally {
    for (final stream in streams) {
      await stream.cancel();
    }
    for (final socket in sockets) {
      await socket.close();
    }
    await host.dispose();
  }
}
