import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/content/pack_store_native.dart';

void main() {
  late Directory directory;
  late HttpServer server;
  late Map<String, dynamic> manifest;
  var corrupt = false;
  String? range;
  final payload = utf8.encode('A verified downloadable sticker payload');
  final digest = sha256.convert(payload).toString();
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wolf-pack-test-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    corrupt = false;
    range = null;
    manifest = {
      'packs': [
        {
          'id': 'test-pack',
          'title': 'Test',
          'version': '1234567890abcdef',
          'size': payload.length,
          'files': [
            {
              'asset': 'assets/stickers/classic/test.png',
              'size': payload.length,
              'sha256': digest,
              'url': '/content/packs/test-pack/1234567890abcdef/$digest',
            },
          ],
        },
      ],
    };
    server.listen((request) async {
      if (request.uri.path == '/content/packs') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(manifest));
      } else {
        range = request.headers.value('range');
        final offset = range == null
            ? 0
            : int.parse(range!.substring(6, range!.length - 1));
        if (offset > 0) {
          request.response.statusCode = 206;
          request.response.headers.set(
            'content-range',
            'bytes $offset-${payload.length - 1}/${payload.length}',
          );
        }
        request.response.add(
          corrupt
              ? List.filled(payload.length - offset, 0)
              : payload.sublist(offset),
        );
      }
      await request.response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });
  PackStore store() => PackStore(
    directory: directory,
    base: Uri.parse('http://127.0.0.1:${server.port}'),
  );
  test(
    'Installation vérifiée, reprise partielle et disponibilité après redémarrage',
    () async {
      final s = store();
      await s.refresh();
      final part = File(
        '${directory.path}/test-pack/1234567890abcdef/$digest.part',
      );
      await part.parent.create(recursive: true);
      await part.writeAsBytes(payload.take(7).toList());
      await s.install('test-pack');
      expect(range, 'bytes=7-');
      expect(s.installed('test-pack'), true);
      expect(
        await File(
          s.pathFor('assets/stickers/classic/test.png')!,
        ).readAsBytes(),
        payload,
      );
      final restarted = store();
      await restarted.initialize();
      expect(restarted.installed('test-pack'), true);
      await restarted.remove('test-pack');
      expect(restarted.pathFor('assets/stickers/classic/test.png'), isNull);
    },
  );
  test('Une empreinte incorrecte ne publie jamais le fichier', () async {
    final s = store();
    await s.refresh();
    corrupt = true;
    await expectLater(s.install('test-pack'), throwsFormatException);
    expect(s.installed('test-pack'), false);
    expect(s.pathFor('assets/stickers/classic/test.png'), isNull);
  });
  test(
    'Un chemin sortant du catalogue est refusé avant téléchargement',
    () async {
      (manifest['packs'][0]['files'][0] as Map)['asset'] =
          'assets/../../secret';
      final s = store();
      await expectLater(s.refresh(), throwsFormatException);
      expect(s.packs, isEmpty);
    },
  );
  test(
    'Une mise à jour conserve les anciens fichiers utilisables avant son installation',
    () async {
      final s = store();
      await s.refresh();
      await s.install('test-pack');
      final previous = s.pathFor('assets/stickers/classic/test.png');
      manifest['packs'][0]['version'] = 'abcdef1234567890';
      manifest['packs'][0]['files'][0]['url'] =
          '/content/packs/test-pack/abcdef1234567890/$digest';
      await s.refresh();
      expect(s.installed('test-pack'), false);
      expect(s.pathFor('assets/stickers/classic/test.png'), previous);
      final restarted = store();
      await restarted.initialize();
      expect(restarted.pathFor('assets/stickers/classic/test.png'), previous);
    },
  );
}
