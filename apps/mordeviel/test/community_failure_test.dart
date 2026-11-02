import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/community/community_failure.dart';

void main() {
  test('Une erreur HTML de Nginx garde son vrai code HTTP', () {
    expect(
      () => decodeCommunityResponse(502, '<html>Bad Gateway</html>'),
      throwsA(
        isA<CommunityFailure>()
            .having((e) => e.status, 'HTTP', 502)
            .having((e) => e.message, 'message', contains('HTTP 502')),
      ),
    );
  });
  test('Identifiants incorrects : le message du serveur reste lisible', () {
    expect(
      () => decodeCommunityResponse(
        401,
        '{"detail":"Pseudo, email ou mot de passe incorrect."}',
      ),
      throwsA(
        isA<CommunityFailure>().having(
          (e) => e.message,
          'message',
          'Pseudo, email ou mot de passe incorrect.',
        ),
      ),
    );
  });
  test('Une page HTML à la place du JSON n’est pas une panne réseau', () {
    expect(
      () => decodeCommunityResponse(200, '<html>Proxy</html>'),
      throwsA(
        isA<CommunityFailure>().having(
          (e) => e.code,
          'code',
          'invalid_response',
        ),
      ),
    );
    expect(
      decodeCommunityResponse(200, '{"token":"fixture"}')['token'],
      'fixture',
    );
  });
  test('Internet, HTTPS et délai dépassé ont des messages distincts', () {
    expect(
      communityTransportFailure(const SocketException('offline')).code,
      'network',
    );
    expect(
      communityTransportFailure(
        const HandshakeException('invalid certificate'),
      ).code,
      'tls',
    );
    expect(communityTransportFailure(TimeoutException('slow')).code, 'timeout');
  });
}
