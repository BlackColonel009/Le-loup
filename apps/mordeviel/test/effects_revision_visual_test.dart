import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/village/blood_splatter.dart';
import 'package:mordeviel/village/electricity.dart';
import 'package:mordeviel/village/mayor_shatter.dart';
import 'package:mordeviel/village/sentence_separation.dart';
import 'package:mordeviel/village/elimination_damage.dart';
import 'package:mordeviel/village/ceremonies.dart';

void main() {
  testWidgets('Le mandat se brise avant la réplique et l’élimination du rôle', (
    tester,
  ) async {
    var spoken = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showElimination(
                context,
                name: 'Le Maire',
                role: 'villager',
                cause: 'vote',
                wasMayor: true,
                onRevealed: () => spoken++,
              ),
              child: const Text('Révéler'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Révéler'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(MayorShatter), findsOneWidget);
    expect(spoken, 0);
    await tester.pump(const Duration(milliseconds: 2200));
    expect(spoken, 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retourner au village'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final effect in ['horror', 'intense', 'elder', 'mayor', 'hunter']) {
    testWidgets('Aperçu détaillé $effect', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final asset = effect == 'horror'
          ? 'assets/cards/horror/werewolf.png'
          : effect == 'elder'
          ? 'assets/cards/elder.png'
          : 'assets/cards/intense/werewolf_intense.jpg';
      final image = FileImage(File(asset));
      final mayor = FileImage(File('assets/cards/mayor.png'));
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final context = tester.element(find.byType(Scaffold));
      await tester.runAsync(() async {
        await precacheImage(image, context);
        await precacheImage(mayor, context);
        await precacheImage(
          const AssetImage('assets/effects/bullet_hole.png'),
          context,
        );
      });
      final key = GlobalKey();
      for (final p in [.2, .5, .85, 1.0]) {
        Widget card = Image(image: image, fit: BoxFit.fill);
        if (['horror', 'intense'].contains(effect)) {
          card = SentenceSeparation(
            progress: p,
            edition: effect,
            seed: 3,
            child: card,
          );
        }
        if (effect == 'mayor') {
          card = MayorShatter(
            progress: p,
            mayorCard: Image(image: mayor, fit: BoxFit.fill),
            child: card,
          );
        }
        if (effect == 'hunter') {
          card = EliminationDamage(progress: p, cause: 'hunter', child: card);
        }
        if (effect == 'elder') {
          card = Stack(
            fit: StackFit.expand,
            children: [
              card,
              CustomPaint(painter: ElderLightning(p)),
            ],
          );
        }
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              home: Scaffold(
                backgroundColor: const Color(0xFF090D16),
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: SizedBox(width: 280, height: 400, child: card),
                    ),
                    if (effect == 'horror')
                      IgnorePointer(
                        child: CustomPaint(
                          painter: BloodSplatterPainter(p, seed: 71),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_EFFECTS') && p == .5) {
          await tester.runAsync(() async {
            final raster =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await raster.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '../../.tmp/effect-$effect.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            raster.dispose();
          });
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
