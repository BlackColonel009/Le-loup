import 'dart:async';
import 'dart:convert';
import 'dart:io';

class OnlineGameException implements Exception {
  const OnlineGameException(this.message, {this.status});
  final String message;
  final int? status;
  factory OnlineGameException.response(int status, String body) {
    String? detail;
    try {
      final data = jsonDecode(body);
      if (data is Map && data['detail'] is String) {
        final value = (data['detail'] as String).trim();
        if (value.isNotEmpty && value.length <= 500 && !value.contains('<'))
          detail = value;
      }
    } catch (_) {
      /* Never show an HTML proxy error or parsing traceback. */
    }
    return OnlineGameException(
      detail ??
          switch (status) {
            401 =>
              'Ta session a expiré. Reconnecte-toi à la communauté puis réessaie.',
            403 =>
              'Ton compte ne peut pas effectuer cette action. Vérifie les accès à ta collection ou contacte le support.',
            404 =>
              'Ce salon est fermé ou introuvable. Demande une nouvelle invitation au MDJ.',
            409 =>
              'Cette action n’est plus disponible dans l’état actuel du salon. Actualise puis réessaie.',
            429 =>
              'Trop de tentatives rapprochées. Patiente quelques minutes avant de réessayer.',
            502 || 503 || 504 =>
              'Le service de jeu est momentanément indisponible. Réessaie dans quelques minutes.',
            _ =>
              'Le service de jeu n’a pas pu effectuer cette action. Réessaie ; si cela persiste, contacte le support.',
          },
      status: status,
    );
  }
  @override
  String toString() => message;
}

String gameFailureMessage(Object failure, {bool online = true}) {
  if (failure is OnlineGameException) return failure.message;
  if (failure is HandshakeException)
    return 'La connexion sécurisée au jeu a échoué. Vérifie la date et l’heure de ton appareil ; si cela persiste, contacte le support.';
  if (failure is SocketException)
    return online
        ? 'Impossible de joindre le jeu. Vérifie ta connexion Internet puis réessaie.'
        : 'Impossible de joindre le salon. Vérifie que les appareils utilisent le même Wi-Fi et que le salon est encore ouvert.';
  if (failure is TimeoutException)
    return 'Le jeu met trop de temps à répondre. Vérifie ta connexion puis réessaie.';
  if (failure is WebSocketException)
    return 'La connexion en direct au salon n’a pas pu être établie. Vérifie que le salon est encore ouvert puis réessaie.';
  if (failure is StateError) return failure.message;
  if (failure is FormatException)
    return 'Les informations du salon sont invalides. Vérifie le code ou demande une nouvelle invitation au MDJ.';
  return 'Cette action n’a pas pu aboutir. Réessaie ; si cela persiste, contacte le support.';
}
