import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/lobby_native.dart';
import 'package:local_host/local_host.dart';

void main() {
  test('URL publique et code sans jeton dans les liens', () {
    final base = onlineServerUri('https://jeu.example');
    expect(
      onlineSocketUri(base, '123456').toString(),
      'wss://jeu.example/rooms/123456/ws',
    );
    expect(
      onlineSocketUri(base, '123456', host: true).toString(),
      'wss://jeu.example/rooms/123456/host',
    );
    expect(
      () => onlineServerUri('https://secret@jeu.example'),
      throwsFormatException,
    );
    expect(() => onlineSocketUri(base, '123'), throwsFormatException);
  });
  testWidgets('Formulaire en ligne séparé du réseau local', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LocalLobbyScreen(online: true)),
    );
    await tester.pumpAndSettle();
    final server = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Serveur en ligne',
    );
    await tester.scrollUntilVisible(
      find.text('legendeofwolf.newtechnologiestg.com'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(server, findsNothing);
    expect(find.text('legendeofwolf.newtechnologiestg.com'), findsOneWidget);
    expect(find.textContaining('127.0.0.1'), findsNothing);
    expect(find.text('Scanner pour rejoindre'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
