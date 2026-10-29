import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'package:mordeviel/services/game_background_session.dart';

Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('État du salon non reçu');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test(
    'La reprise automatique réutilise le jeton après une vraie fermeture du transport',
    () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      final client = LobbyClient();
      final sockets = <WebSocket>[];
      final joins = <Map>[];
      final resumed = Completer<void>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((raw) {
          final message = jsonDecode(raw as String) as Map;
          if (message['type'] != 'room.join' &&
              message['type'] != 'room.resume') {
            return;
          }
          joins.add(message);
          socket.add(
            jsonEncode({
              'type': 'room.joined',
              'id': 'same-player',
              'token': 'private-resume-token',
            }),
          );
          socket.add(jsonEncode({'type': 'room.snapshot', 'phase': 'lobby'}));
          if (joins.length == 1) {
            Future<void>.delayed(
              const Duration(milliseconds: 50),
              () => socket.close(1001, 'Transport redémarré'),
            );
          } else if (!resumed.isCompleted) {
            resumed.complete();
          }
        });
      });
      addTearDown(() async {
        await client.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      });
      await client.connect('127.0.0.1:${server.port}', '123456', 'Masque');
      await resumed.future.timeout(const Duration(seconds: 5));
      expect(joins.map((m) => m['type']), ['room.join', 'room.resume']);
      expect(joins.last['token'], 'private-resume-token');
      expect(client.id, 'same-player');
    },
  );
  test(
    'Un joueur prêt en arrière-plan garde sa place et récupère son rôle après le lancement',
    () async {
      final host = LocalHost();
      final clients = List.generate(4, (_) => LobbyClient());
      addTearDown(() async {
        for (final client in clients) {
          await client.dispose();
        }
        await host.dispose();
      });
      await host.start(nickname: 'MDJ', port: 0, bindAddress: '127.0.0.1');
      for (var i = 0; i < clients.length; i++) {
        await clients[i].connect(
          '127.0.0.1:${host.port}',
          host.code,
          'Joueur $i',
        );
        await waitUntil(() => clients[i].id != null);
        clients[i].setReady(true);
      }
      await waitUntil(
        () =>
            (host.snapshot['players'] as List).every((p) => p['ready'] == true),
      );
      final player = clients.first;
      final originalId = player.id;
      player.setBackground(true);
      await waitUntil(
        () => (host.snapshot['players'] as List).first['background'] == true,
      );
      await player.disconnect();
      await waitUntil(
        () => (host.snapshot['players'] as List).first['connected'] == false,
      );
      expect((host.snapshot['players'] as List).first['ready'], isTrue);
      expect(host.launchError, isNull);
      host.startGame();
      final role = player.events.firstWhere((e) => e['type'] == 'game.role');
      await player.reconnect();
      expect(
        (await role.timeout(const Duration(seconds: 3)))['role'],
        isNotEmpty,
      );
      expect(player.id, originalId);
      expect((host.snapshot['players'] as List).length, 4);
    },
  );

  test(
    'Une coupure conserve la confirmation, mais quitter le salon libère la place',
    () async {
      final host = LocalHost(reconnectGrace: const Duration(milliseconds: 300));
      final client = LobbyClient();
      addTearDown(() async {
        await client.dispose();
        await host.dispose();
      });
      await host.start(nickname: 'MDJ', port: 0, bindAddress: '127.0.0.1');
      await client.connect('127.0.0.1:${host.port}', host.code, 'Masque');
      await waitUntil(() => client.id != null);
      client.setReady(true);
      await waitUntil(
        () => (host.snapshot['players'] as List).first['ready'] == true,
      );
      final originalId = client.id;
      await client.disconnect();
      await waitUntil(
        () => (host.snapshot['players'] as List).first['connected'] == false,
      );
      expect((host.snapshot['players'] as List).first['ready'], isTrue);
      await client.reconnect();
      await waitUntil(
        () => (host.snapshot['players'] as List).first['connected'] == true,
      );
      expect(client.id, originalId);
      expect((host.snapshot['players'] as List).first['ready'], isTrue);
      await client.dispose();
      await waitUntil(() => (host.snapshot['players'] as List).isEmpty);
    },
  );

  test(
    'Une place abandonnée est retirée à la fin du délai de reconnexion',
    () async {
      final host = LocalHost(reconnectGrace: const Duration(milliseconds: 70));
      final client = LobbyClient();
      addTearDown(() async {
        await client.dispose();
        await host.dispose();
      });
      await host.start(nickname: 'MDJ', port: 0, bindAddress: '127.0.0.1');
      await client.connect('127.0.0.1:${host.port}', host.code, 'Masque');
      await waitUntil(() => client.id != null);
      await client.disconnect();
      await waitUntil(() => (host.snapshot['players'] as List).isEmpty);
    },
  );

  test(
    'Une seule alerte au lancement en arrière-plan, aucune au retour dans une partie',
    () {
      final alert = GameStartAlertTracker();
      expect(alert.update('lobby', background: false), isFalse);
      expect(alert.update('dealt', background: true), isTrue);
      expect(alert.update('dealt', background: true), isFalse);
      expect(alert.update('night', background: false), isFalse);
      final foreground = GameStartAlertTracker();
      foreground.update('lobby', background: false);
      expect(foreground.update('dealt', background: false), isFalse);
      expect(foreground.update('night', background: true), isFalse);
      expect(
        GameStartAlertTracker().update('night', background: true),
        isFalse,
      );
    },
  );
}
