import '../community/community_session.dart';

class SocialError implements Exception {
  const SocialError(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class SocialApi {
  static SocialApi instance = SocialApi();
  Future<CommunitySession?> session() async => null;
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async => throw const SocialError(
    401,
    'Ouvre l’application native pour les fonctions sociales.',
  );
}
