import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/cards/card_gallery.dart';
import 'package:mordeviel/cards/classic_role.dart';
import 'package:mordeviel/village/sulfuron_scene.dart';

void main() {
  test('Chaque édition possède ses règles et son illustration', () {
    expect(File('assets/village/fire.gif').existsSync(), isTrue);
    expect(File('assets/village/fire-65.gif').existsSync(), isTrue);
    expect(File('assets/cards/sulfuron.png').existsSync(), isTrue);
    expect(
      File('assets/cards/intense/sulfuron_intense.jpg').existsSync(),
      isTrue,
    );
    expect(File('assets/cards/horror/sulfuron.png').existsSync(), isTrue);
    expect(configuredRole('sulfuron').camp, 'Solitaire');
    expect(
      configuredRole('sulfuron', edition: 'horror').details,
      contains('accusateur'),
    );
    expect(
      configuredRole('sulfuron', edition: 'intense').details,
      contains('définitive'),
    );
  });
  testWidgets('Le Test réussi 1 place le GIF animé sur le haut de la cavité', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 280,
          height: 400,
          child: BurningCard(
            progress: .5,
            child: const ColoredBox(color: Colors.amber),
          ),
        ),
      ),
    );
    final fire = tester.widget<Image>(find.byType(Image));
    expect(fire.image, isA<AssetImage>());
    expect((fire.image as AssetImage).assetName, 'assets/village/fire-65.gif');
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Le feu montant conserve le GIF fourni à la place des flammes dessinées',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 280,
            height: 400,
            child: BottomUpGifBurningCard(
              progress: .5,
              child: const ColoredBox(color: Colors.amber),
            ),
          ),
        ),
      );
      final fire = tester.widget<Image>(find.byType(Image));
      expect((fire.image as AssetImage).assetName, 'assets/village/fire.gif');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'La combustion retire progressivement le papier jusqu’à la cendre',
    (tester) async {
      for (final progress in [0.0, .2, .4, .6, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 280,
                height: 400,
                child: BurningCard(
                  progress: progress,
                  child: const ColoredBox(color: Colors.amber),
                ),
              ),
            ),
          ),
        );
        final path = tester
            .widget<ClipPath>(find.byType(ClipPath).first)
            .clipper!
            .getClip(const Size(280, 400));
        expect(path.contains(const Offset(140, 200)), progress == 0);
        expect(path.contains(const Offset(20, 20)), progress < 1);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'Le Bluff reste identifié comme annonce douteuse, portrait et paysage',
    (tester) async {
      if (const bool.fromEnvironment('CAPTURE_SULFURON')) {
        await tester.runAsync(() async {
          for (final entry in {
            'Cormorant': 'assets/fonts/CormorantGaramond[wght].ttf',
            'VillageSans': 'assets/fonts/SourceSans3[wght].ttf',
          }.entries) {
            final bytes = await File(entry.value).readAsBytes();
            await (FontLoader(
              entry.key,
            )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
          }
        });
      }
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      for (final size in [const Size(390, 844), const Size(844, 390)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark().copyWith(
                textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: 'VillageSans',
                ),
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showSulfuronScene(
                      context,
                      event: {
                        'kind': 'revelation',
                        'role': 'werewolf',
                        'power': 'bluff',
                        'text':
                            'Vous serez désorientés, mais vous ne me trouverez pas.',
                      },
                      playerName: 'Alice',
                      ambience: CardAmbience.classic,
                    ),
                    child: const Text('Ouvrir'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            const ResizeImage(
              AssetImage('assets/cards/werewolf.jpg'),
              width: 768,
            ),
            boundary.currentContext!,
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();
        expect(find.text('Alice'), findsOneWidget);
        expect(find.byType(RoleCardFront), findsOneWidget);
        expect(
          tester
              .widget<RawImage>(
                find.descendant(
                  of: find.byType(RoleCardFront),
                  matching: find.byType(RawImage),
                ),
              )
              .image,
          isNotNull,
        );
        expect(
          find.textContaining('cette carte peut être fausse'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_SULFURON') &&
            size.width == 390) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '.tmp/sulfuron-bluff.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets('Le gain de vie affiche sa quantité et la limite au vote', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showSulfuronScene(
                context,
                event: {'kind': 'soul_gained', 'lives': 2},
                playerName: 'Sulfuron',
                ambience: CardAmbience.classic,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('1 vie en réserve'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('+1 vie volée'), findsOneWidget);
    expect(find.text('2 vies en réserve'), findsOneWidget);
    expect(find.textContaining('Le vote, le poison'), findsOneWidget);
    expect(find.byType(RoleCardFront), findsNothing);
    expect(find.byType(BurningCard), findsNothing);
    expect(find.byType(BottomUpGifBurningCard), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
  });
}
