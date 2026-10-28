import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/village/guardian_aura.dart';

void main() {
  for (final intense in [false, true]) {
    testWidgets(
      'Protection $intense sans bloquer la maison et animations réduites',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Stack(
                  children: [
                    TextButton(
                      onPressed: () => taps++,
                      child: const Text('Maison'),
                    ),
                    SizedBox(
                      width: 148,
                      height: 170,
                      child: GuardianAura(intense: intense),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Maison'));
        expect(taps, 1);
        expect(
          find.bySemanticsLabel('Protection du Salvateur'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
