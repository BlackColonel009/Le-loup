import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Deux joueurs Android : arrivée et statut prêt', (tester) async {
    const address = String.fromEnvironment('TEST_HOST');
    const code = String.fromEnvironment('TEST_ROOM_CODE');
    expect(
      address.isNotEmpty && code.isNotEmpty,
      isTrue,
      reason:
          'Fournir TEST_HOST et TEST_ROOM_CODE pour un salon de test ouvert.',
    );
    final results = <String, String>{};
    for (final legacyHeartbeat in [true, false]) {
      final sockets = <WebSocket>[];
      final streams = <StreamIterator<dynamic>>[];
      Future<Map<String, dynamic>> next(
        StreamIterator<dynamic> stream,
        String type,
      ) async {
        while (await stream.moveNext().timeout(const Duration(seconds: 5))) {
          final event =
              jsonDecode(stream.current as String) as Map<String, dynamic>;
          if (event['type'] == 'error') {
            throw StateError(event['message'] as String);
          }
          if (event['type'] == type) return event;
        }
        throw StateError(
          'Connexion fermée : ${sockets.map((s) => s.closeCode).toList()}',
        );
      }

      try {
        for (var i = 0; i < 2; i++) {
          final socket = await WebSocket.connect(
            'ws://$address/ws',
            compression: CompressionOptions.compressionDefault,
          );
          if (legacyHeartbeat) {
            socket.pingInterval = const Duration(seconds: 10);
          }
          sockets.add(socket);
          final stream = StreamIterator<dynamic>(socket.asBroadcastStream());
          streams.add(stream);
          socket.add(
            jsonEncode({
              'version': 1,
              'type': 'room.join',
              'code': code,
              'nickname': 'Test ${legacyHeartbeat ? 'P' : 'S'} $i',
            }),
          );
          await next(stream, 'room.joined');
          await next(stream, 'room.snapshot');
        }
        await next(streams.first, 'room.snapshot');
        await Future<void>.delayed(const Duration(seconds: 25));
        sockets.first.add(
          jsonEncode({'version': 1, 'type': 'player.ready', 'ready': true}),
        );
        await next(streams.first, 'room.snapshot');
        await next(streams.last, 'room.snapshot');
        results[legacyHeartbeat ? 'double_ping' : 'serveur_seul'] = 'OK';
      } catch (error) {
        results[legacyHeartbeat ? 'double_ping' : 'serveur_seul'] = error
            .toString();
      } finally {
        for (final socket in sockets) {
          await socket.close();
        }
        for (final stream in streams) {
          await stream.cancel();
        }
      }
    }
    // Aucune clé privée de session ni attribution n'est imprimée.
    // ignore: avoid_print
    print('Diagnostic transport Android : $results');
    expect(results['serveur_seul'], 'OK');
  });
}
