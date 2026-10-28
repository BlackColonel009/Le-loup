import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/design/opening_screen.dart';
import 'package:mordeviel/design/drifting_backdrop.dart';
import 'package:mordeviel/design/game_theme.dart';

void main() {
  if (const bool.fromEnvironment('CAPTURE_OPENING')) {
    setUpAll(() async {
      for (final entry in {
        'VillageSans': 'assets/fonts/SourceSans3[wght].ttf',
        'Cormorant': 'assets/fonts/CormorantGaramond[wght].ttf',
      }.entries) {
        final bytes = await File(entry.value).readAsBytes();
        await (FontLoader(
          entry.key,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
    testWidgets('Captures des griffures, de la déchirure et du logo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: GameTheme.classic,
            debugShowCheckedModeBanner: false,
            home: OpeningScreen(
              onStart: () {},
              onScratch: (_) {},
              onComplete: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/branding/logo.png'),
          tester.element(find.byType(OpeningScreen)),
        );
      });
      await tester.pump();
      for (final (name, delay) in [
        ('claws', 800),
        ('tear', 900),
        ('logo', 1100),
      ]) {
        await tester.pump(Duration(milliseconds: delay));
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final picture =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await picture.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/previews').create(recursive: true);
          await File(
            'build/previews/opening_$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          picture.dispose();
        });
      }
    });
  }
  for (final size in [const Size(320, 568), const Size(1000, 400)]) {
    testWidgets('Deux griffures et révélation finie à $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strikes = <int>[];
      var started = 0, completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: GameTheme.classic,
          home: OpeningScreen(
            onStart: () => started++,
            onScratch: strikes.add,
            onComplete: () => completed++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(strikes, [1]);
      await tester.pump(const Duration(milliseconds: 750));
      expect(strikes, [1, 2]);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(completed, 0);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(started, 1);
      expect(completed, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(strikes, [1, 2]);
      expect(completed, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Passer attend la préparation, puis termine une seule fois', (
    tester,
  ) async {
    final ready = Completer<void>();
    var completed = 0;
    final strikes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: OpeningScreen(
          ready: ready.future,
          onStart: () {},
          onScratch: strikes.add,
          onComplete: () => completed++,
        ),
      ),
    );
    await tester.tap(find.text('Passer'));
    await tester.pump(const Duration(seconds: 5));
    expect(completed, 0);
    ready.complete();
    await tester.pump();
    await tester.pump();
    expect(completed, 1);
    expect(strikes, isEmpty);
    await tester.tap(find.text('Passer'));
    expect(completed, 1);
  });
  testWidgets('Animations réduites : logo et fondu, sans déchirure', (
    tester,
  ) async {
    final strikes = <int>[];
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: OpeningScreen(
            onStart: () {},
            onScratch: strikes.add,
            onComplete: () => completed++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(completed, 1);
    expect(strikes, isEmpty);
    expect(find.bySemanticsLabel('Logo de Mordeviel Legendary'), findsOneWidget);
  });
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
