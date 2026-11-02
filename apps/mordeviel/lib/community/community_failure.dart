import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CommunityFailure extends StateError {
  CommunityFailure(super.message, {required this.code, this.status});
  final String code;
  final int? status;
  @override
  String toString() => message;
}

Map<String, dynamic> decodeCommunityResponse(int status, String body) {
  Map<String, dynamic>? data;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) data = decoded;
  } on FormatException {
    // Nginx and proxies can return HTML/plain text; status remains useful.
  }
  if (status >= 300) {
    final detail = data?['detail'];
    final message = detail is String && detail.trim().isNotEmpty
        ? detail
        : switch (status) {
            >= 500 =>
              'Le service communauté rencontre une erreur (HTTP $status). Réessaie dans un instant.',
            401 =>
              'Connexion refusée. Vérifie tes identifiants ou reconnecte-toi.',
            403 =>
              'L’accès à la communauté a été refusé. Contacte le support si nécessaire.',
            404 || 405 =>
              'Le service de connexion est introuvable (HTTP $status). Vérifie que l’application et le serveur sont à jour.',
            429 => 'Trop de tentatives. Patiente un peu avant de réessayer.',
            >= 300 && < 400 =>
              'Le service de connexion a renvoyé une redirection inattendue. Réessaie ou contacte le support.',
            _ =>
              'La demande n’a pas été acceptée (HTTP $status). Vérifie les champs saisis.',
          };
    throw CommunityFailure(message, code: 'http', status: status);
  }
  if (data == null) {
    throw CommunityFailure(
      'La communauté a renvoyé une réponse inattendue. Réessaie ou contacte le support.',
      code: 'invalid_response',
      status: status,
    );
  }
  return data;
}

CommunityFailure communityTransportFailure(Object error) {
  if (error is CommunityFailure) return error;
  if (error is TimeoutException) {
    return CommunityFailure(
      'Le service communauté met trop de temps à répondre. Réessaie avec une connexion stable.',
      code: 'timeout',
    );
  }
  if (error is TlsException) {
    return CommunityFailure(
      'La connexion sécurisée à la communauté est impossible. Vérifie la date et l’heure de l’appareil, puis réessaie.',
      code: 'tls',
    );
  }
  if (error is SocketException) {
    return CommunityFailure(
      'Impossible de joindre la communauté. Vérifie Internet ou essaie un autre réseau.',
      code: 'network',
    );
  }
  return CommunityFailure(
    'L’échange avec la communauté a été interrompu. Réessaie dans un instant.',
    code: 'transport',
  );
}
