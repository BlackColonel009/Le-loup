import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/village/sentence_separation.dart';

void main() {
  for (final edition in ['classic', 'intense', 'horror']) {
    testWidgets(
      'Séparation $edition et aperçu sans débordement de mise en page',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final asset = edition == 'classic'
            ? 'assets/cards/werewolf.jpg'
            : edition == 'intense'
            ? 'assets/cards/intense/werewolf_intense.jpg'
            : 'assets/cards/horror/werewolf.png';
        final boundary = GlobalKey();
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        final context = tester.element(find.byType(Scaffold));
        await tester.runAsync(
          () => precacheImage(FileImage(File(asset)), context),
        );
        if (const bool.fromEnvironment('CAPTURE_SENTENCE')) {
          await tester.runAsync(() async {
            final data = await File(
              'assets/fonts/SourceSans3[wght].ttf',
            ).readAsBytes();
            await (FontLoader(
              'VillageSans',
            )..addFont(Future.value(ByteData.sublistView(data)))).load();
          });
        }
        for (final p in [.2, .7, 1.0]) {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  brightness: Brightness.dark,
                  fontFamily: 'VillageSans',
                ),
                home: Scaffold(
                  backgroundColor: const Color(0xFF080B10),
                  body: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sentence · $edition',
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 48),
                      Center(
                        child: SizedBox(
                          width: 270,
                          height: 400,
                          child: SentenceSeparation(
                            progress: p,
                            edition: edition,
                            seed: 2,
                            child: Image.file(File(asset), fit: BoxFit.fill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            find.bySemanticsLabel('Carte séparée après le vote du village'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        if (const bool.fromEnvironment('CAPTURE_SENTENCE')) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '../../.tmp/sentence-$edition.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
