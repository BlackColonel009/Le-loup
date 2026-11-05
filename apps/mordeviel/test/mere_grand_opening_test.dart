import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/events/mere_grand_screen.dart';
import 'package:mordeviel/services/immersion_preferences.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('RENDER_MERE_GRAND')) {
      for (final font in [
        ('VillageSans', 'assets/fonts/SourceSans3[wght].ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
      }
    }
  });

  test('Le parchemin précède le titre, qui précède Bientôt disponible', () {
    final rolling = mereGrandOpeningAt(const Duration(milliseconds: 1000));
    expect(rolling.unroll, inExclusiveRange(0, 1));
    expect(rolling.title, 0);
    expect(rolling.soon, 0);
    final opened = mereGrandOpeningAt(const Duration(milliseconds: 1750));
    expect(opened.unroll, 1);
    expect(opened.title, 0);
    expect(opened.soon, 0);
    final title = mereGrandOpeningAt(const Duration(milliseconds: 2400));
    expect(title.unroll, 1);
    expect(title.title, inExclusiveRange(0, 1));
    expect(title.soon, 0);
    final wait = mereGrandOpeningAt(const Duration(milliseconds: 2950));
    expect(wait.title, 1);
    expect(wait.soon, 0);
    expect(mereGrandOpeningAt(mereGrandOpeningDuration), (
      unroll: 1.0,
      title: 1.0,
      soon: 1.0,
    ));
  });

  Future<void> ready(
    WidgetTester tester,
    GlobalKey boundary,
    Size size, {
    bool reduced = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final wasLight = ImmersionPreferences.instance.lightEffects;
    ImmersionPreferences.instance.lightEffects = reduced;
    addTearDown(() => ImmersionPreferences.instance.lightEffects = wasLight);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: GameTheme.classic,
          home: const MereGrandPosterScreen(soundEnabled: false),
        ),
      ),
    );
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any((w) => w.painter is MereGrandScrollPainter)) {
        await tester.pump();
        return;
      }
    }
    fail('Le PNG du parchemin n’a pas été chargé.');
  }

  for (final size in [const Size(432, 768), const Size(844, 390)]) {
    testWidgets('L’ouverture est fluide et peut être passée à $size', (
      tester,
    ) async {
      final boundary = GlobalKey();
      await ready(tester, boundary, size);
      expect(find.text('Passer l’animation'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      final paint =
          tester
                  .widgetList<CustomPaint>(find.byType(CustomPaint))
                  .firstWhere((w) => w.painter is MereGrandScrollPainter)
                  .painter
              as MereGrandScrollPainter;
      expect(paint.unroll, inExclusiveRange(0, 1));
      expect(paint.title, 0);
      expect(paint.soon, 0);
      await tester.tap(find.text('Passer l’animation'));
      await tester.pump();
      expect(find.text('Passer l’animation'), findsNothing);
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .scaleEnabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Le mode mouvements réduits montre directement l’affiche', (
    tester,
  ) async {
    await ready(tester, GlobalKey(), const Size(390, 844), reduced: true);
    expect(find.text('Passer l’animation'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Prévisualisation vidéo du rendu réel', (tester) async {
    if (!const bool.fromEnvironment('RENDER_MERE_GRAND')) return;
    final boundary = GlobalKey();
    await ready(tester, boundary, const Size(432, 768));
    final directory = Directory('.tmp/mere-grand-frames');
    await tester.runAsync(() => directory.create(recursive: true));
    for (var i = 0; i < 109; i++) {
      if (i > 0) await tester.pump(const Duration(microseconds: 41667));
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/frame-${i.toString().padLeft(3, '0')}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(find.text('Passer l’animation'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
