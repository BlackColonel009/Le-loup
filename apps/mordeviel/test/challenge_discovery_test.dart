import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/challenges/challenge_discovery.dart';

Map<String, dynamic> item(
  String id,
  int value, {
  bool complete = false,
  bool claimed = false,
}) => {
  'id': id,
  'title': 'Défi $id',
  'description': 'Terminer dix parties.',
  'progress': value,
  'target': 10,
  'completed_at': complete ? 1 : null,
  'claimed_at': claimed ? 2 : null,
};

void main() {
  test(
    'L’aperçu priorise les cadeaux puis les défis en cours et ceux à commencer',
    () {
      final sorted = orderedChallengePreview([
        item('nouveau', 0),
        item('recu', 10, complete: true, claimed: true),
        item('en-cours', 3),
        item('cadeau', 10, complete: true),
      ]);
      expect(sorted.map((c) => c['id']), ['cadeau', 'en-cours', 'nouveau']);
    },
  );
  for (final size in [const Size(320, 568), const Size(900, 420)]) {
    testWidgets('L’aperçu se ferme et affiche les jauges vides à $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showChallengeDiscovery(
                  context,
                  load: () async => {
                    'preview': true,
                    'challenges': [
                      item('un', 0),
                      item('deux', 0),
                      item('trois', 0),
                    ],
                    'pending_count': 0,
                  },
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('Vos défis du moment'), findsOneWidget);
      final gauge = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('discovery-un')),
      );
      expect(gauge.value, 0);
      final close = find.text('Fermer et continuer');
      expect(tester.getRect(close).bottom, lessThan(size.height));
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(ChallengeDiscoveryDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Le raccourci d’accueil est directement cliquable', (
    tester,
  ) async {
    var clicked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChallengesHomeShortcut(onTap: () => clicked = true),
        ),
      ),
    );
    expect(find.text('Défis & récompenses'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-challenges')));
    expect(clicked, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
