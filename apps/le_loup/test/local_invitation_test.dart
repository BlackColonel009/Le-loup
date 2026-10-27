import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';

void main() {
  test('Une invitation conserve adresse, port et code commençant par zéro', () {
    final source = LocalInvitation(
      address: '192.168.1.12:54321',
      code: '001234',
    );
    final decoded = LocalInvitation.parse(source.payload);
    expect(decoded.address, source.address);
    expect(decoded.code, '001234');
    expect(
      Uri.parse(source.payload).queryParameters.keys,
      containsAll(['v', 'address', 'code']),
    );
  });
  for (final payload in [
    'https://example.com',
    'wifi:S:MonWifi;;',
    '',
    'leloup://join?v=2&address=192.168.1.2:8080&code=123456',
    'leloup://join?v=1&address=192.168.1.2:8080',
    'leloup://join?v=1&address=192.168.1.2:8080&code=123456&code=654321',
    'leloup://join?v=1&address=192.168.1.2:8080&code=123456&token=secret',
    'leloup://join/path?v=1&address=192.168.1.2:8080&code=123456',
    'leloup://user@join?v=1&address=192.168.1.2:8080&code=123456',
    'leloup://join:90?v=1&address=192.168.1.2:8080&code=123456',
    'leloup://join?v=1&address=192.168.1.2:8080&code=123456#extra',
  ]) {
    test(
      'Invitation rejetée : $payload',
      () => expect(() => LocalInvitation.parse(payload), throwsFormatException),
    );
  }
  for (final address in [
    'example.com:8080',
    '192.168.1.999:8080',
    '0.0.0.0:8080',
    '224.0.0.1:8080',
    '192.168.1.2:0',
    '192.168.1.2:65536',
    '192.168.1.2:8080/ws',
  ]) {
    test(
      'Adresse QR invalide : $address',
      () => expect(
        () => LocalInvitation(address: address, code: '123456'),
        throwsFormatException,
      ),
    );
  }
  test('Code incomplet et contenu excessif refusés', () {
    expect(
      () => LocalInvitation(address: '10.0.0.1:8080', code: '12345'),
      throwsFormatException,
    );
    expect(() => LocalInvitation.parse('x' * 513), throwsFormatException);
  });
}
