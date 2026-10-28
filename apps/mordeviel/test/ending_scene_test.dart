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
import 'package:mordeviel/village/ending_data.dart';
import 'package:mordeviel/village/victory_scene.dart';

const capture = bool.fromEnvironment('CAPTURE_ENDINGS');

void main() {
  testWidgets('Deux morts : une réplique par carte, glissement puis suivante', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                for (final role in ['seer', 'guardian']) {
                  await showElimination(
                    context,
                    name: role,
                    role: role,
                    cause: 'vote',
                    hasNext: role == 'seer',
                    lastWords: deathSpeeches[role]!.text,
                    onRevealed: () => events.add('parole:$role'),
                    onDismissed: () => events.add('stop:$role'),
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
    expect(events, ['parole:seer']);
    expect(find.text('« ${deathSpeeches['seer']!.text} »'), findsOneWidget);
    expect(find.text('Carte suivante'), findsOneWidget);
    await tester.drag(find.byType(RoleCardFront), const Offset(0, 170));
    await tester.pumpAndSettle();
    expect(events, ['parole:seer', 'stop:seer', 'parole:guardian']);
    expect(find.text('« ${deathSpeeches['guardian']!.text} »'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Retourner au village'));
    await tester.pumpAndSettle();
    expect(events.last, 'stop:guardian');
  });
  setUpAll(() async {
    if (capture) {
      for (final entry in {
        'Cormorant': 'assets/fonts/CormorantGaramond[wght].ttf',
        'VillageSans': 'assets/fonts/SourceSans3[wght].ttf',
        'MaterialIcons':
            'C:/bibliotheque/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final bytes = await File(entry.value).readAsBytes();
        await (FontLoader(
          entry.key,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    }
  });
  for (final winner in gameEndings.keys) {
    testWidgets('Fin de partie $winner : annonce, vainqueurs et retour', (
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
            debugShowCheckedModeBanner: false,
            theme: GameTheme.classic,
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => showVictory(
                    context,
                    game: {
                      'winner': winner,
                      'winner_ids': ['logan'],
                    },
                    players: [
                      {'id': 'logan', 'nickname': 'Logan'},
                      {'id': 'other', 'nickname': 'Autre'},
                    ],
                    ambience: CardAmbience.intense,
                  ),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text(gameEndings[winner]!.title), findsOneWidget);
      expect(find.text('À l’honneur : Logan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (capture && (winner == 'village' || winner == 'wolves')) {
        await tester.runAsync(() async {
          final context = tester.element(find.byType(VictoryScene));
          await precacheImage(
            AssetImage(
              'assets/cards/intense/${gameEndings[winner]!.role}_intense.jpg',
            ),
            context,
          );
        });
        await tester.pumpAndSettle();
        await snapshot(tester, boundary, 'ending_$winner');
      }
      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.tap(find.text('Voir les rôles et retourner au village'));
      await tester.pumpAndSettle();
      expect(find.byType(VictoryScene), findsNothing);
    });
  }
  testWidgets('Petit paysage, texte agrandi et animations réduites', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(640, 360),
            disableAnimations: true,
            textScaler: TextScaler.linear(1.5),
          ),
          child: const VictoryScene(
            game: {'winner': 'white_wolf'},
            players: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Voir les rôles et retourner au village'),
      150,
    );
    expect(tester.takeException(), isNull);
  });
  for (final secret in [false, true]) {
    testWidgets(
      'Ancien : malédiction, identité ${secret ? 'secrète' : 'révélée'}',
      (tester) async {
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: GameTheme.classic,
              home: Builder(
                builder: (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () => showElimination(
                      context,
                      name: 'Logan',
                      role: secret ? null : 'elder',
                      cause: 'vote',
                      cursed: true,
                    ),
                    child: const Text('Ouvrir'),
                  ),
                ),
              ),
            ),
          ),
        );
        if (capture && !secret) {
          await tester.runAsync(() async {
            await precacheImage(
              ResizeImage(
                AssetImage(configuredRole('elder').asset),
                width: 768,
              ),
              tester.element(find.text('Ouvrir')),
            );
          });
        }
        await tester.tap(find.text('Ouvrir'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1800));
        expect(
          find.text('Les pouvoirs du camp Village sont désactivés.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Rôle :'),
          secret ? findsNothing : findsOneWidget,
        );
        if (capture && !secret) await snapshot(tester, boundary, 'elder_curse');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Retourner au village'));
        await tester.pumpAndSettle();
        expect(find.text('Ouvrir'), findsOneWidget);
      },
    );
  }
}

Future<void> snapshot(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/previews/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
