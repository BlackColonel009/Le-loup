import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/cards/card_gallery.dart';
import 'package:mordeviel/cards/classic_role.dart';
import 'package:mordeviel/village/wolf_devour_video.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'coins_test.dart' show CoinVideoPlatform;

void main() {
  testWidgets('La vidéo attend le réaffichage après une interruption', (
    tester,
  ) async {
    final previous = VideoPlayerPlatform.instance;
    final platform = CoinVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() async {
      VideoPlayerPlatform.instance = previous;
      await platform.events.close();
    });
    final concealed = ValueNotifier(false);
    addTearDown(concealed.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: concealed,
          builder: (_, hidden, _) => WolfDevourVideo(
            role: configuredRole('seer'),
            videoPath: 'downloaded-devour.mp4',
            whiteWolfFinishing: false,
            concealed: hidden,
            onPlaybackStarted: () {},
            onPlaybackFailed: () => fail('Lecture simulée impossible'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(platform.plays, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    concealed.value = true;
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.plays, 1);
    expect(find.byType(RoleCardFront), findsNothing);
    concealed.value = false;
    await tester.pump();
    expect(platform.plays, 2);
    expect(platform.creations, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('La carte horreur se révèle avant la dévoration', () {
    expect(wolfDevourCardRevealProgress(0), 0);
    expect(wolfDevourCardRevealProgress(.1), greaterThan(0));
    expect(wolfDevourCardRevealProgress(.16), 1);
    expect(wolfDevourCardRevealProgress(1), 1);
  });

  for (final (name, whiteWolf, approach, bite, after) in [
    ('Loup-Garou', false, 4550, 4750, 5000),
    ('Loup Blanc', true, 7400, 7670, 7820),
  ]) {
    testWidgets('$name : la carte se comprime puis disparaît', (tester) async {
      final previous = VideoPlayerPlatform.instance;
      final platform = CoinVideoPlatform();
      var completions = 0;
      VideoPlayerPlatform.instance = platform;
      addTearDown(() async {
        VideoPlayerPlatform.instance = previous;
        await platform.events.close();
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 533,
              child: WolfDevourVideo(
                role: configuredRole(whiteWolf ? 'werewolf' : 'seer'),
                videoPath: whiteWolf
                    ? whiteWolfDevourVideoAsset
                    : wolfDevourVideoAsset,
                whiteWolfFinishing: whiteWolf,
                concealed: false,
                onPlaybackStarted: () {},
                onPlaybackFailed: () => fail('Lecture simulée impossible'),
                onPlaybackCompleted: () => completions++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final cardFrame = find.ancestor(
        of: find.byType(RoleCardFront),
        matching: find.byType(FittedBox),
      );
      Future<void> position(int milliseconds) async {
        platform.position = Duration(milliseconds: milliseconds);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();
      }

      await position(approach);
      final before = tester.getSize(cardFrame);
      await position(bite);
      final crushed = tester.getSize(cardFrame);
      expect(crushed.height, lessThan(before.height / 2));
      expect(crushed.width, greaterThan(before.width / 2));
      await position(after);
      expect(find.byType(RoleCardFront), findsNothing);
      expect(completions, 0);
      platform.events.add(VideoEvent(eventType: VideoEventType.completed));
      await tester.pump();
      expect(completions, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('La vidéo dépend du prédateur et de la carte dévorée', () {
    expect(
      wolfDevourVideoFor(
        cause: 'night',
        ambience: CardAmbience.horror,
        role: 'seer',
      ),
      wolfDevourVideoAsset,
    );
    for (final role in [
      'werewolf',
      'alpha_wolf',
      'wolf_father',
      'white_wolf',
    ]) {
      expect(
        wolfDevourVideoFor(
          cause: 'white_wolf',
          ambience: CardAmbience.horror,
          role: role,
        ),
        whiteWolfDevourVideoAsset,
        reason: '$role doit employer la finition du Loup Blanc',
      );
    }
    expect(
      wolfDevourVideoFor(
        cause: 'white_wolf',
        ambience: CardAmbience.horror,
        role: 'seer',
      ),
      wolfDevourVideoAsset,
    );
    expect(
      wolfDevourVideoFor(
        cause: 'night',
        ambience: CardAmbience.horror,
        role: null,
      ),
      isNull,
    );
    expect(
      wolfDevourVideoFor(
        cause: 'night',
        ambience: CardAmbience.classic,
        role: 'seer',
      ),
      isNull,
    );
    expect(
      wolfDevourVideoFor(
        cause: 'vote',
        ambience: CardAmbience.horror,
        role: 'seer',
      ),
      isNull,
    );
  });
}
