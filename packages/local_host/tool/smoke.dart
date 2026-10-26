import 'dart:convert';
import 'dart:io';

import '../lib/local_host.dart';

Future<void> main() async {
  final host = LocalHost();
  final client = HttpClient();
  try {
    await host.start(port: 0);
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${host.port}/health'),
    );
    final response = await request.close();
    final body = jsonDecode(await utf8.decoder.bind(response).join());
    if (response.statusCode != 200 || body['protocol'] != '1') {
      throw StateError('Diagnostic local invalide : $body');
    }
    final missing = await client.getUrl(
      Uri.parse('http://127.0.0.1:${host.port}/unknown'),
    );
    final missingResponse = await missing.close();
    await missingResponse.drain<void>();
    if (missingResponse.statusCode != 404) {
      throw StateError('Une route inconnue doit renvoyer 404.');
    }
    print('Local host: health + 404 OK');
  } finally {
    client.close(force: true);
    await host.stop();
  }
}
