import 'dart:convert';
import 'dart:io';
import 'package:local_host/local_host.dart';

Future<Map<String, dynamic>> loadPublicContent(String path) async {
  final base = onlineServerUri(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000',
    ),
  );
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client
        .getUrl(base.resolve(path))
        .timeout(const Duration(seconds: 8));
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const HttpException('Contenu indisponible.');
    }
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 10));
    return jsonDecode(text) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}
