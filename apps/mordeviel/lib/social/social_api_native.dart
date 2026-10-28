import 'dart:convert';
import 'dart:io';
import 'package:local_host/local_host.dart' show onlineServerUri;
import '../community/community_session.dart';
import '../services/server_config.dart';

class SocialError implements Exception {
  const SocialError(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class SocialApi {
  static SocialApi instance = SocialApi();
  final base = onlineServerUri(apiBaseUrl);
  late final sessions = CommunitySessionStore(base.toString());
  Future<CommunitySession?> session() => sessions.load();
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    final token = deviceToken ?? (await session())?.token;
    if (token == null) {
      throw const SocialError(
        401,
        'Connecte-toi à la communauté pour retrouver ton village.',
      );
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .openUrl(method, base.resolve(path))
          .timeout(const Duration(seconds: 12));
      request.headers.set('Authorization', 'Bearer $token');
      request.followRedirects = false;
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1048576) {
          throw const SocialError(502, 'Réponse trop volumineuse.');
        }
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      final data = Map<String, dynamic>.from(decoded as Map);
      if (response.statusCode >= 400) {
        throw SocialError(
          response.statusCode,
          data['detail'] is String
              ? data['detail'] as String
              : 'Cette action est momentanément indisponible.',
        );
      }
      return data;
    } on SocialError {
      rethrow;
    } catch (_) {
      throw const SocialError(
        503,
        'Le village est momentanément inaccessible. Réessaie.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
