import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/cards/classic_role.dart';
import 'package:le_loup/cards/game_codex.dart';

void main() {
  test('La variante Voyante remplace le texte standard', () {
    expect(configuredRole('seer').summary, contains('rôle exact'));
    expect(
      configuredRole('seer', seerCampOnly: true).summary,
      contains('le camp'),
    );
    expect(configuredRole('witch', seerCampOnly: true).id, 'witch');
  });

  testWidgets('Le Codex expose la composition, sans attributions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showGameCodex(context, {
                'deck': {
                  'villager': 2,
                  'werewolf': 1,
                  'seer': 1,
                  'witch': 0,
                  'hunter': 0,
                },
                'seer_camp_only': true,
              }),
              child: const Text('Codex'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    expect(find.text('Voyante × 1'), findsOneWidget);
    expect(find.text('Sorcière × 0'), findsNothing);
    expect(
      find.text('Variante : la Voyante découvre le camp uniquement.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Voyante × 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('seul le camp est révélé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
