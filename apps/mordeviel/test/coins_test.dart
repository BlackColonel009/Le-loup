import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:mordeviel/coins/coin_widgets.dart';
import 'package:mordeviel/coins/coin_reward_scene.dart';
import 'package:mordeviel/coins/wallet_screen.dart';
import 'package:mordeviel/challenges/reward_claim_dialog.dart';
import 'package:mordeviel/challenges/challenges_screen.dart';
import 'package:mordeviel/village/victory_scene.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/social/social_service.dart';

class CoinApi extends SocialApi {
  int claims = 0;
  Map<String, dynamic> get reward => {
    'match_id': 'finished',
    'user_id': 1,
    'amount': 73,
    'balance': 1073,
    'eligible': true,
    'won': true,
    'nights': 3,
    'theme': 'horror',
    'claimed_at': null,
  };
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (path.endsWith('/claim')) {
      claims++;
      return {...reward, 'claimed_at': 1234};
    }
    if (path == '/coins/me') {
      return {
        'user_id': 1,
        'balance': 1073,
        'rewards': [reward],
      };
    }
    return reward;
  }
}

class CoinVideoPlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast();
  Duration position = Duration.zero;
  int plays = 0;
  int creations = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    creations++;
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) {
    scheduleMicrotask(
      () => events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(540, 960),
          duration: const Duration(seconds: 10),
        ),
      ),
    );
    return events.stream;
  }

  @override
  Future<void> play(int id) async {
    plays++;
  }

  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> dispose(int id) async {}
  @override
  Future<void> setVolume(int id, double volume) async {}
  @override
  Future<void> setLooping(int id, bool looping) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<Duration> getPosition(int id) async => position;
  @override
  Future<void> seekTo(int id, Duration value) async {
    position = value;
  }

  @override
  Widget buildView(int id) => const ColoredBox(color: Colors.black);
}

void main() {
  setUp(() => rootBundle.evict('assets/rewards/coin_impacts.json'));
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_COINS')) {
      for (final entry in [
        ('VillageSans', 'assets/fonts/SourceSans3[wght].ttf'),
        ('Cormorant', 'assets/fonts/CormorantGaramond[wght].ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(entry.$1)..addFont(rootBundle.load(entry.$2))).load();
      }
    }
  });
  test(
    'Le compteur progresse uniquement aux impacts et atteint le total exact',
    () {
      expect(
        [
          0,
          100,
          299,
          300,
          700,
        ].map((t) => coinsAtImpact(40, t, [100, 300, 700])),
        [0, 13, 13, 26, 40],
      );
      expect(compactCoins(500), '500');
      expect(compactCoins(1000), '1K');
      expect(compactCoins(1500), '1,5K');
      expect(compactCoins(22000), '22K');
      expect(compactCoins(999999), '1M');
    },
  );
  test(
    'La difficulté du défi choisit le coffre, même avec une bordure animée',
    () {
      expect(
        challengeChestTier([
          {
            'chest_tier': 'classic',
            'rewards': [
              {'kind': 'border', 'id': 'amber'},
            ],
          },
        ]),
        RewardChestTier.classic,
      );
      expect(
        challengeChestTier([
          {'chest_tier': 'epic', 'rewards': []},
        ]),
        RewardChestTier.epic,
      );
      expect(
        challengeChestTier([
          {'chest_tier': 'epic', 'rewards': []},
          {'chest_tier': 'premium', 'rewards': []},
        ]),
        RewardChestTier.premium,
      );
    },
  );
  for (final size in [const Size(360, 740), const Size(740, 360)]) {
    testWidgets(
      'Passer garde le gain, affiche son montant et confirme une fois à $size',
      (tester) async {
        final old = SocialApi.instance;
        final api = CoinApi();
        SocialApi.instance = api;
        final service = SocialService.instance;
        final oldId = service.userId;
        final oldBalance = service.coinBalance;
        service.userId = 1;
        service.coinBalance = 0;
        addTearDown(() {
          SocialApi.instance = old;
          service.userId = oldId;
          service.coinBalance = oldBalance;
        });
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: GameTheme.classic,
              home: CoinRewardScene(receipt: api.reward, videoEnabled: false),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Passer'));
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('Vous avez gagné'), findsOneWidget);
        expect(find.text('+73'), findsOneWidget);
        expect(find.text('Lunes d’or'), findsOneWidget);
        expect(api.claims, 1);
        expect(service.coinBalance, 1073);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_COINS') &&
            size.width < size.height) {
          await tester.runAsync(() async {
            for (final image in tester.widgetList<Image>(find.byType(Image))) {
              await precacheImage(image.image, boundary.currentContext!);
            }
          });
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '.tmp/coins-reward-portrait.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('La bourse affiche le solde exact et les coffres non ouverts', (
    tester,
  ) async {
    final old = SocialApi.instance;
    SocialApi.instance = CoinApi();
    addTearDown(() => SocialApi.instance = old);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: GameTheme.classic,
        home: const WalletScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1073'), findsOneWidget);
    expect(find.text('0 Lunes bronze'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ouvrir le coffre'), 180);
    expect(find.text('Ouvrir le coffre'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Le carnet filtre les défis par coffre', (tester) async {
    final data = <String, dynamic>{
      'challenges': [
        for (final tier in ['classic', 'epic', 'premium'])
          {
            'id': tier,
            'title': 'Défi $tier',
            'description': 'Un objectif',
            'category': 'Test',
            'target': 3,
            'progress': 0,
            'rewards': <Map>[],
            'completed_at': null,
            'chest_tier': tier,
          },
      ],
      'pending_challenges': <Map>[],
      'pending_count': 0,
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: GameTheme.classic,
        home: ChallengesScreen(initialData: data, autoPresentRewards: false),
      ),
    );
    await tester.pumpAndSettle();
    final filter = find.widgetWithText(ChoiceChip, 'Épique · moyen');
    await tester.scrollUntilVisible(filter, 200);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Défi epic'), 150);
    expect(find.text('Défi epic'), findsOneWidget);
    expect(find.text('Défi classic'), findsNothing);
    expect(find.text('Défi premium'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Continuer depuis la victoire ouvre le coffre de la partie', (
    tester,
  ) async {
    final old = SocialApi.instance;
    final api = CoinApi();
    SocialApi.instance = api;
    addTearDown(() => SocialApi.instance = old);
    await tester.pumpWidget(
      MaterialApp(
        theme: GameTheme.classic,
        home: VictoryScene(
          game: const {'winner': 'village', 'winner_ids': <String>[]},
          players: const [],
          matchId: 'finished',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final next = find.text('Continuer · ouvrir mon coffre');
    await tester.scrollUntilVisible(next, 180);
    await tester.tap(next);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.byType(CoinRewardScene), findsOneWidget);
    await tester.tap(find.text('Passer'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('+73'), findsOneWidget);
    expect(api.claims, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('La vidéo est lue puis le compteur finit sur le montant exact', (
    tester,
  ) async {
    final old = SocialApi.instance;
    final api = CoinApi();
    SocialApi.instance = api;
    final previous = VideoPlayerPlatform.instance;
    final platform = CoinVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() async {
      SocialApi.instance = old;
      VideoPlayerPlatform.instance = previous;
      await platform.events.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: GameTheme.classic,
        home: CoinRewardScene(receipt: api.reward),
      ),
    );
    for (var i = 0; i < 35 && platform.plays == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(
      platform.plays,
      greaterThan(0),
      reason:
          'created=${platform.creations}; claims=${api.claims}; ${tester.allWidgets.whereType<Text>().map((w) => w.data).join(' / ')}',
    );
    platform.position = const Duration(seconds: 4);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final counter = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').startsWith('+'),
    );
    expect(counter, findsWidgets);
    expect(find.text('Vous avez gagné'), findsNothing);
    platform.position = const Duration(seconds: 10);
    platform.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Vous avez gagné'), findsOneWidget);
    expect(find.text('+73'), findsOneWidget);
    expect(api.claims, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
