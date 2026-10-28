import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/cards/classic_role.dart';
import 'package:mordeviel/village/ceremonies.dart';
import 'package:mordeviel/village/village_map.dart';
import 'package:local_host/local_host.dart';

void main() {
  test('Villageoise : variante cosmétique du même rôle', () {
    final male = configuredRole('villager');
    final female = configuredRole('villager', feminine: true);
    expect(female.id, male.id);
    expect(female.summary, male.summary);
    expect(female.details, male.details);
    expect(female.name, 'Villageoise');
    expect(female.asset, endsWith('villager_female.png'));
    final game = NightGame({
      'w': 'werewolf',
      'v': 'villager',
      'a': 'villager',
      'b': 'villager',
    });
    game.phase = 'day';
    game.alive.remove('v');
    expect(
      () => game.act('v', {
        'action': 'day.chat',
        'text': 'secret',
        'phase_revision': game.publicState['phase_revision'],
      }),
      throwsStateError,
    );
  });
  for (final intense in [false, true]) {
    testWidgets(
      'Illustration de sentence réservée au pack Intense : $intense',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SentenceWheel(
                  intense: intense,
                  isHost: false,
                  onSpin: () {},
                  name: (_) => 'Alice',
                  game: {
                    'phase': 'vote_result',
                    'vote_result': {'eliminated': 'a'},
                    'sentence_options': NightGame.sentences,
                    'sentence': {
                      'id': 's1',
                      'index': 0,
                      'label': 'Guillotine',
                      'remaining_ms': 0,
                    },
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel('Illustration de la sentence Guillotine'),
          intense ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Fantôme animé non interactif et mouvement lent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 56,
            height: 70,
            child: SpectatorGhost(slot: 1, name: 'Alice'),
          ),
        ),
      ),
    );
    await tester.pump();
    final before = tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(SpectatorGhost),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .clone();
    await tester.pump(const Duration(seconds: 2));
    final after = tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(SpectatorGhost),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform;
    expect(before, isNot(after));
    expect(find.byType(IgnorePointer), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
