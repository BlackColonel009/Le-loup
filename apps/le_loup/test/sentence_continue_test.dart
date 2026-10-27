import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/village/ceremonies.dart';

void main() {
  testWidgets(
    'La sentence donne un bouton de reprise après confirmation serveur',
    (tester) async {
      var continued = 0;
      Widget screen(int remaining, String phase) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SentenceWheel(
              game: {
                'phase': phase,
                'vote_result': {'eliminated': 'p0'},
                'sentence_options': <String>[],
                'sentence': {
                  'id': 'sentence-1',
                  'index': 3,
                  'label': 'Cachot',
                  'remaining_ms': remaining,
                },
              },
              isHost: true,
              onSpin: () {},
              onContinue: () => continued++,
              name: (_) => 'Alice',
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(4500, 'vote_result'));
      await tester.pumpAndSettle();
      expect(find.text('Sentence : Cachot'), findsOneWidget);
      final pending = find.widgetWithText(
        FilledButton,
        'La roue termine son annonce…',
      );
      expect(tester.widget<FilledButton>(pending).onPressed, isNull);
      await tester.pumpWidget(screen(0, 'vote_result'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Commencer la nuit suivante'));
      await tester.tap(find.text('Commencer la nuit suivante'));
      expect(continued, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in {
    'hunter': 'Reprendre le dernier tir du Chasseur',
    'ended': 'Voir le résultat de la partie',
  }.entries) {
    testWidgets('La roue respecte la phase ${entry.key}', (tester) async {
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SentenceWheel(
                game: {
                  'phase': entry.key,
                  'vote_result': {'eliminated': 'p0'},
                  'sentence_options': <String>[],
                  'sentence': {
                    'id': 'sentence-1',
                    'index': 0,
                    'label': 'Guillotine',
                    'remaining_ms': 0,
                  },
                },
                isHost: true,
                onSpin: () {},
                onContinue: () => continued = true,
                name: (_) => 'Alice',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Commencer la nuit suivante'), findsNothing);
      await tester.ensureVisible(find.text(entry.value));
      await tester.tap(find.text(entry.value));
      expect(continued, isTrue);
    });
  }
}
