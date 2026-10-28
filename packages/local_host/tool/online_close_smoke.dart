import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../lib/local_host.dart';

Future<void> scenario({
  bool dropSocket = false,
  bool retry = false,
  bool missing = false,
}) async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  WebSocket? peer;
  var deletes = 0;
  final host = OnlineHost('http://127.0.0.1:${server.port}');
  final serving = server.listen((request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      peer = await WebSocketTransformer.upgrade(request);
      peer!.listen((raw) {
        final auth = jsonDecode(raw as String) as Map;
        if (auth['token'] != 'private-host-credential')
          throw StateError('Jeton manquant.');
        peer!.add(
          jsonEncode({
            'type': 'host.snapshot',
            'room': {'code': '123456', 'phase': 'lobby', 'deck': {}},
          }),
        );
      });
      return;
    }
    if (request.method == 'POST' && request.uri.path == '/rooms') {
      await request.drain<void>();
      request.response.statusCode = 201;
      request.response.write(
        jsonEncode({'code': '123456', 'host_token': 'private-host-credential'}),
      );
    } else if (request.method == 'DELETE' &&
        request.uri.path == '/rooms/123456') {
      deletes++;
      if (request.headers.value('Authorization') !=
          'Bearer private-host-credential') {
        request.response.statusCode = 403;
      } else {
        request.response.statusCode = missing
            ? 404
            : retry && deletes == 1
            ? 503
            : 204;
      }
    } else {
      request.response.statusCode = 404;
    }
    await request.response.close();
  });
  try {
    await host.start();
    if (dropSocket) {
      final lost = host.updates.firstWhere(
        (event) => event['online_connected'] == false,
      );
      await peer!.close();
      await lost.timeout(const Duration(seconds: 3));
    }
    if (retry) {
      var refused = false;
      try {
        await host.closeRoom();
      } catch (_) {
        refused = true;
      }
      if (!refused)
        throw StateError('Une fermeture refusée doit rester réessayable.');
    }
    await host.closeRoom();
    await host.dispose();
    if (deletes != (retry ? 2 : 1))
      throw StateError('Fermeture manquante ou dupliquée.');
  } finally {
    await host.dispose();
    await peer?.close();
    await serving.cancel();
    await server.close(force: true);
  }
}

Future<void> main() async {
  await scenario();
  await scenario(dropSocket: true);
  await scenario(retry: true);
  await scenario(missing: true);
  print(
    'Fermeture en ligne : socket actif, socket perdu, nouvel essai et salon déjà fermé OK.',
  );
}
