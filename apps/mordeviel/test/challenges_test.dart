import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/src/night_game.dart';
import 'package:mordeviel/audio/classic_audio.dart';
import 'package:mordeviel/challenges/challenge_card.dart';
import 'package:mordeviel/challenges/challenges_screen.dart';

Map<String, dynamic> challenge({
  int before = 1,
  int progress = 2,
  bool completed = false,
}) => {
  'id': 'crocs',
  'title': 'Premiers crocs',
  'category': 'Maîtrise',
  'description':
      'Participer à une dévoration réussie dans 2 parties différentes.',
  'before': before,
  'progress': progress,
  'target': 2,
  'completed_at': completed ? 1793690000 : null,
  'newly_completed': completed,
  'rewards': [
    {'kind': 'border', 'id': 'amber', 'title': 'Ambre solaire'},
  ],
};

void action(
  NightGame g,
  String who,
  String type, {
  String? target,
  List<String>? targets,
  bool save = false,
}) => g.act(who, {
  'action': type,
  'phase_revision': g.revision,
  'target': target,
  'targets': targets,
  'save': save,
});

void main() {
  testWidgets(
    'La jauge progresse depuis la valeur précédente puis révèle le palier',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChallengeCard(
                challenge: challenge(completed: true),
                animate: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('NOUVELLE RÉCOMPENSE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Une jauge partielle part du bord gauche et conserve toute sa piste',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeCard(challenge: challenge(progress: 1)),
          ),
        ),
      );
      final track = tester.getRect(
        find.byKey(const ValueKey('challenge-bar-crocs')),
      );
      final fill = tester.getRect(
        find.byKey(const ValueKey('challenge-fill-crocs')),
      );
      expect(fill.left, track.left);
      expect(fill.width, closeTo(track.width / 2, .01));
    },
  );

  for (final size in [const Size(320, 568), const Size(900, 420)]) {
    testWidgets(
      'Bilan lisible sans débordement à $size, progrès privés et récompense visible',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final oldMute = ClassicAudio.instance.muted;
        ClassicAudio.instance.muted = true;
        addTearDown(() => ClassicAudio.instance.muted = oldMute);
        await tester.pumpWidget(
          MaterialApp(
            home: ChallengesScreen(
              matchId: 'test-match',
              initialData: {
                'eligible': true,
                'changes': [challenge(completed: true)],
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1700));
        expect(find.text('Votre légende grandit'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Ambre solaire'), 180);
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.text('2 / 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('Le mode entraînement explique l’absence de récompenses', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChallengesScreen(
          matchId: 'practice',
          initialData: {
            'eligible': false,
            'reason': 'Partie d’entraînement avec bots.',
            'changes': [],
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Partie d’entraînement avec bots.'), findsOneWidget);
    expect(find.text('Consulter tous mes défis'), findsOneWidget);
  });

  test(
    'Les effets de protection et de dévoration sont précis et restent secrets avant la fin',
    () {
      final g = NightGame({
        'w': 'werewolf',
        'g': 'guardian',
        'v': 'villager',
        'a': 'villager',
        'b': 'villager',
      });
      g.startNight();
      g.callNight('guardian');
      action(g, 'g', 'guardian.protect', targets: ['v']);
      g.advance();
      g.callNight('wolves');
      action(g, 'w', 'wolves.choose', target: 'v');
      g.advance();
      expect(g.publicState.containsKey('history'), isFalse);
      expect(g.publicState.containsKey('dealt_roles'), isFalse);
      g.finishNight();
      g.advance();
      expect(g.alive.contains('v'), isTrue);
      g.startVote();
      for (final id in g.alive.toList()) {
        action(g, id, 'vote.cast', target: 'w');
      }
      g.advance();
      expect(g.phase, 'ended');
      final history = g.publicState['history'] as List;
      final blocked = history.where((e) => e['effect'] == 'protected').single;
      expect(blocked['actor'], 'g');
      expect(blocked['target'], 'v');
      expect(g.publicState['dealt_roles']['w'], 'werewolf');
      expect(history.where((e) => e['cause'] == 'night'), isEmpty);
    },
  );

  test(
    'Une dévoration confirmée nomme les membres de la meute dans le bilan seulement',
    () {
      final g = NightGame({
        'w': 'werewolf',
        'v': 'villager',
        'a': 'villager',
        'b': 'villager',
      });
      g.startNight();
      g.callNight('wolves');
      action(g, 'w', 'wolves.choose', target: 'v');
      g.advance();
      g.finishNight();
      g.advance();
      expect(g.publicState.containsKey('history'), isFalse);
      g.startVote();
      for (final id in g.alive.toList()) {
        action(g, id, 'vote.cast', target: 'w');
      }
      g.advance();
      final death = (g.publicState['history'] as List)
          .where((e) => e['cause'] == 'night')
          .single;
      expect(death['pack_ids'], ['w']);
      expect(death['target'], 'v');
    },
  );
}
