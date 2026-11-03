import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:mordeviel/design/opening_screen.dart';
import 'package:mordeviel/design/drifting_backdrop.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast();
  final calls = <String>[];
  final sources = <DataSource>[];
  final volumes = <double>[];
  bool fail = false, silent = false;
  Duration position = Duration.zero;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    sources.add(options.dataSource);
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    scheduleMicrotask(() {
      if (fail) {
        events.addError(
          PlatformException(code: 'VideoError', message: 'Codec'),
        );
      } else if (!silent) {
        events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            size: const Size(1280, 720),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    });
    return events.stream;
  }

  @override
  Future<void> play(int playerId) async => calls.add('play');
  @override
  Future<void> pause(int playerId) async => calls.add('pause');
  @override
  Future<void> dispose(int playerId) async => calls.add('dispose');
  @override
  Future<void> setVolume(int playerId, double volume) async =>
      volumes.add(volume);
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> seekTo(int playerId, Duration value) async => position = value;
  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.amber);
}

void main() {
  late _VideoPlatform platform;
  setUp(() {
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() => platform.events.close());

  testWidgets(
    'La vidéo locale finit une seule fois et coupe son son avant l’accueil',
    (tester) async {
      var started = 0, completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: OpeningScreen(
            onStart: () => started++,
            onComplete: () {
              expect(platform.calls.last, 'pause');
              completed++;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(started, 1);
      expect(platform.sources.single.asset, OpeningScreen.videoAsset);
      expect(platform.calls, contains('play'));
      platform.events.add(VideoEvent(eventType: VideoEventType.completed));
      await tester.pump();
      await tester.pump();
      expect(completed, 1);
      await tester.tap(find.text('Passer'));
      await tester.pump();
      expect(completed, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(platform.calls, contains('dispose'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Passer attend la préparation sans jouer la vidéo', (
    tester,
  ) async {
    final ready = Completer<void>();
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OpeningScreen(
          ready: ready.future,
          onStart: () {},
          onComplete: () => completed++,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Passer'));
    await tester.pump(const Duration(seconds: 2));
    expect(completed, 0);
    expect(platform.calls, isNot(contains('play')));
    ready.complete();
    await tester.pump();
    await tester.pump();
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'Rotation sans redémarrage, pause et reprise, réglage silencieux',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var completed = 0;
      Widget scene(double volume) => MaterialApp(
        home: OpeningScreen(
          volume: volume,
          onStart: () {},
          onComplete: () => completed++,
        ),
      );
      await tester.pumpWidget(scene(.4));
      await tester.pump();
      await tester.pump();
      expect(platform.volumes.last, .4);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      await tester.pump();
      expect(platform.sources, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(platform.calls.last, 'pause');
      expect(completed, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(platform.calls.last, 'play');
      await tester.pumpWidget(scene(0));
      await tester.pump();
      expect(platform.volumes.last, 0);
      await tester.tap(find.text('Passer'));
      await tester.pump();
      expect(completed, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  for (final fault in ['codec', 'initialisation', 'lecture figée']) {
    testWidgets('Un échec de $fault ne bloque pas le jeu', (tester) async {
      platform.fail = fault == 'codec';
      platform.silent = fault == 'initialisation';
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: OpeningScreen(onStart: () {}, onComplete: () => completed++),
        ),
      );
      await tester.pump();
      await tester.pump();
      if (!platform.fail) {
        for (var i = 0; i < 9; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(completed, 1);
      expect(
        find.bySemanticsLabel('Logo de Mordeviel Legendary'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('Mouvements réduits : logo statique sans lecteur ni son vidéo', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: OpeningScreen(onStart: () {}, onComplete: () => completed++),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(platform.sources, isEmpty);
    expect(completed, 1);
    expect(
      find.bySemanticsLabel('Logo de Mordeviel Legendary'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(320, 568), const Size(1000, 400)]) {
    testWidgets('Image entière et proportions conservées à $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OpeningVideoStage(
              videoSize: Size(1280, 720),
              backdrop: ColoredBox(color: Colors.black),
              child: ColoredBox(key: ValueKey('film'), color: Colors.amber),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(const ValueKey('film')));
      expect(rect.width / rect.height, closeTo(1280 / 720, .001));
      expect(rect.left, greaterThanOrEqualTo(-.01));
      expect(rect.top, greaterThanOrEqualTo(-.01));
      expect(rect.right, lessThanOrEqualTo(size.width + .01));
      expect(rect.bottom, lessThanOrEqualTo(size.height + .01));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Le décor bouge, les commandes restent fixes ; pause en arrière-plan',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                DriftingBackdrop(child: ColoredBox(color: Colors.blue)),
                Center(child: Text('Commande fixe')),
              ],
            ),
          ),
        ),
      );
      final transform = find
          .descendant(
            of: find.byType(DriftingBackdrop),
            matching: find.byType(Transform),
          )
          .first;
      final initial = List<double>.from(
        tester.widget<Transform>(transform).transform.storage,
      );
      final position = tester.getTopLeft(find.text('Commande fixe'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 8));
      final moving = List<double>.from(
        tester.widget<Transform>(transform).transform.storage,
      );
      expect(moving, isNot(initial));
      expect(tester.getTopLeft(find.text('Commande fixe')), position);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.widget<Transform>(transform).transform.storage, moving);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
