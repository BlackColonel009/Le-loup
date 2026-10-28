import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/cards/card_gallery.dart';
import 'package:mordeviel/cards/classic_role.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/village/ceremonies.dart';
import 'package:mordeviel/village/elimination_damage.dart';

void main() {
  test(
    'Trois perforations successives, réellement découpées dans la carte',
    () {
      expect(const BulletDamagePainter(0).visibleImpacts, 0);
      expect(const BulletDamagePainter(.20).visibleImpacts, 1);
      expect(const BulletDamagePainter(.48).visibleImpacts, 2);
      expect(const BulletDamagePainter(1).visibleImpacts, 3);
    },
  );
  testWidgets(
    'Les impacts percent la carte, le poison fait remonter son bord',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 280,
            height: 400,
            child: EliminationDamage(
              cause: 'hunter',
              progress: 1,
              child: ColoredBox(color: Colors.amber),
            ),
          ),
        ),
      );
      final bulletClip = tester
          .widget<ClipPath>(find.byType(ClipPath))
          .clipper!
          .getClip(const Size(280, 400));
      for (final p in bulletPositions) {
        expect(bulletClip.contains(Offset(p.dx * 280, p.dy * 400)), isFalse);
      }
      expect(bulletClip.contains(const Offset(140, 30)), isTrue);
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 280,
            height: 400,
            child: EliminationDamage(
              cause: 'poison',
              progress: 1,
              child: ColoredBox(color: Colors.amber),
            ),
          ),
        ),
      );
      final poisonClip = tester
          .widget<ClipPath>(find.byType(ClipPath))
          .clipper!
          .getClip(const Size(280, 400));
      expect(poisonClip.contains(const Offset(140, 100)), isTrue);
      expect(poisonClip.contains(const Offset(140, 380)), isFalse);
    },
  );
  testWidgets(
    'La réduction des animations conserve les trois impacts et le poison finaux',
    (tester) async {
      for (final cause in ['hunter', 'poison']) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: EliminationDamage(
                cause: cause,
                progress: 0,
                child: const ColoredBox(color: Colors.amber),
              ),
            ),
          ),
        );
        final paint = tester
            .widget<CustomPaint>(find.byType(CustomPaint).last)
            .painter;
        if (cause == 'hunter') {
          expect((paint as BulletDamagePainter).visibleImpacts, 3);
          expect(paint.reduced, isTrue);
        } else {
          expect((paint as PoisonDamagePainter).progress, 1);
          expect(paint.reduced, isTrue);
        }
      }
    },
  );
  testWidgets(
    'Deux victimes : poison puis tir, une réplique par carte et fermeture possible',
    (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  for (final cause in ['poison', 'hunter']) {
                    await showElimination(
                      context,
                      name: 'Victime $cause',
                      role: 'seer',
                      cause: cause,
                      hasNext: cause == 'poison',
                      lastWords: 'Ma dernière parole.',
                      onRevealed: () => events.add('voix:$cause'),
                      onDismissed: () => events.add('fin:$cause'),
                    );
                    if (!context.mounted) return;
                  }
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Éliminé par une potion'), findsOneWidget);
      expect(
        tester.widget<EliminationDamage>(find.byType(EliminationDamage)).cause,
        'poison',
      );
      expect(events, ['voix:poison']);
      await tester.drag(find.byType(RoleCardFront), const Offset(0, 170));
      await tester.pumpAndSettle();
      expect(events, ['voix:poison', 'fin:poison', 'voix:hunter']);
      expect(
        tester.widget<EliminationDamage>(find.byType(EliminationDamage)).cause,
        'hunter',
      );
      expect(find.text('Dernier tir du Chasseur'), findsOneWidget);
      await tester.tap(find.text('Retourner au village'));
      await tester.pumpAndSettle();
      expect(events.last, 'fin:hunter');
    },
  );
  testWidgets('Un rôle caché reste caché avec le poison', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () =>
                  showElimination(context, name: 'Secret', cause: 'poison'),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(RoleCardFront), findsNothing);
    expect(
      find.text('Son rôle reste secret selon les règles du salon.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retourner au village'));
    await tester.pumpAndSettle();
  });
  testWidgets('Les dégâts se dessinent dans tous les thèmes et formats', (
    tester,
  ) async {
    for (final size in [const Size(360, 740), const Size(900, 420)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final ambience in CardAmbience.values) {
        for (final cause in ['hunter', 'poison']) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 220,
                    height: 315,
                    child: EliminationDamage(
                      cause: cause,
                      progress: 1,
                      child: RoleCardFront(
                        role: configuredRole('seer'),
                        ambience: ambience,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('Aperçus des impacts et du poison', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_DAMAGE')) return;
    await tester.runAsync(() async {
      for (final e in {
        'Cormorant': 'assets/fonts/CormorantGaramond[wght].ttf',
        'VillageSans': 'assets/fonts/SourceSans3[wght].ttf',
      }.entries) {
        final bytes = await File(e.value).readAsBytes();
        await (FontLoader(
          e.key,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    for (final cause in ['hunter', 'poison']) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: GameTheme.classic,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showElimination(
                    context,
                    name: 'La Voyante',
                    role: 'seer',
                    cause: cause,
                    ambience: CardAmbience.intense,
                    lastWords: 'Le village doit connaître la vérité.',
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
          const AssetImage('assets/cards/intense/seer_intense.jpg'),
          boundary.currentContext!,
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '../../.tmp/elimination-$cause.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('Retourner au village'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    }
  });
}
