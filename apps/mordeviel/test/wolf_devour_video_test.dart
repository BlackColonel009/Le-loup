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
            revealProgress: 1,
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
