import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/audio/classic_audio.dart';
import 'package:mordeviel/challenges/reward_claim_dialog.dart';
import 'package:mordeviel/challenges/challenges_screen.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/village/victory_scene.dart';

Map<String, dynamic> gift([int number = 1]) => {
  'id': 'gift-$number',
  'title': 'Première victoire $number',
  'category': 'Premiers pas',
  'description': 'Remporter une partie.',
  'target': 1,
  'progress': 1,
  'before': 0,
  'completed_at': 1793690000,
  'claimed_at': null,
  'newly_completed': true,
  'rewards': [
    {'kind': 'border', 'id': 'amber', 'title': 'Ambre solaire'},
  ],
};

class RewardsApi extends SocialApi {
  int claims = 0;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (path == '/challenges/claim') {
      claims++;
      return {
        'claimed_ids': ['gift-1'],
        'claimed_count': 1,
        'pending_count': 0,
        'challenges': [
          {...gift(), 'claimed_at': 1793690100},
        ],
      };
    }
    throw StateError(path);
  }
}

void main() {
  setUp(() {
    ClassicAudio.instance.muted = true;
  });
  tearDown(() {
    ClassicAudio.instance.muted = false;
  });

  for (final size in [const Size(320, 568), const Size(900, 420)]) {
    testWidgets('Le bouton Réclamer reste visible avec 20 cadeaux à $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardClaimDialog(
              challenges: [for (var i = 0; i < 20; i++) gift(i)],
              claim: (_) async => {},
              onClaimed: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final button = find.widgetWithText(
        FilledButton,
        'Réclamer mes 20 récompenses',
      );
      expect(button, findsOneWidget);
      final rect = tester.getRect(button);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(
        find.text('Plus tard · mes cadeaux restent disponibles'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'Le cadeau ne s’ouvre qu’après confirmation et le double clic est bloqué',
    (tester) async {
      final response = Completer<Map<String, dynamic>>();
      var calls = 0, applied = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardClaimDialog(
              challenges: [gift()],
              claim: (_) {
                calls++;
                return response.future;
              },
              onClaimed: (_) => applied = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Réclamer ma récompense'));
      await tester.pump();
      expect(find.text('Récupération…'), findsOneWidget);
      expect(applied, isFalse);
      await tester.tap(find.text('Récupération…'));
      expect(calls, 1);
      response.complete({'claimed_count': 1});
      await tester.pump();
      expect(find.text('Le coffre s’ouvre…'), findsOneWidget);
      expect(find.text('Super, continuer !'), findsNothing);
      expect(find.text('Ambre solaire'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.tap(find.text('Passer l’animation'));
      await tester.pump();
      expect(applied, isTrue);
      expect(find.text('Ces trésors sont à vous !'), findsOneWidget);
      expect(find.text('Super, continuer !'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Une panne conserve le cadeau et propose de réessayer', (
    tester,
  ) async {
    var calls = 0, applied = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RewardClaimDialog(
            challenges: [gift()],
            claim: (_) async {
              if (++calls == 1) {
                throw const SocialError(
                  503,
                  'Connexion interrompue, réessayez.',
                );
              }
              return {'claimed_count': 1};
            },
            onClaimed: (_) => applied = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Réclamer ma récompense'));
    await tester.pump();
    expect(find.text('Connexion interrompue, réessayez.'), findsOneWidget);
    expect(applied, isFalse);
    await tester.tap(find.text('Réclamer ma récompense'));
    await tester.pump();
    expect(applied, isTrue);
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Modal automatique, Plus tard puis récupération depuis le carnet',
    (tester) async {
      final oldApi = SocialApi.instance;
      final api = RewardsApi();
      SocialApi.instance = api;
      addTearDown(() => SocialApi.instance = oldApi);
      await tester.pumpWidget(
        MaterialApp(
          home: ChallengesScreen(
            matchId: 'match',
            initialData: {
              'eligible': true,
              'changes': [gift()],
              'pending_challenges': [gift()],
              'pending_count': 1,
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RewardClaimDialog), findsOneWidget);
      await tester.tap(
        find.text('Plus tard · mes cadeaux restent disponibles'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RewardClaimDialog), findsNothing);
      expect(api.claims, 0);
      await tester.scrollUntilVisible(
        find.text('Réclamer mes récompenses'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Réclamer mes récompenses'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Réclamer ma récompense').last);
      await tester.pump();
      expect(api.claims, 1);
      await tester.tap(find.text('Passer l’animation'));
      await tester.pump();
      await tester.tap(find.text('Super, continuer !'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('VOS CADEAUX VOUS ATTENDENT'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'La victoire déclenche la présentation sans action du joueur, une seule fois',
    (tester) async {
      var prompts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: VictoryScene(
            game: const {'winner': 'village', 'winner_ids': []},
            players: const [],
            onRewardsReady: (_) async {
              prompts++;
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2900));
      expect(prompts, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(prompts, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
