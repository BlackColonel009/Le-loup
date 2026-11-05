import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/village/victory_chibis.dart';
import 'package:mordeviel/content/pack_messages.dart';

void main() {
  test('Victory poses are downloadable and excluded from the app bundle', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('    - assets/chibis/')));
    final catalog =
        jsonDecode(File('../../shared/content/catalog.json').readAsStringSync())
            as Map;
    final pack =
        (catalog['packs'] as List).singleWhere(
              (p) => p['id'] == 'victory-poses',
            )
            as Map;
    final assets = (pack['files'] as List).map((f) => f['asset']).toSet();
    for (final role in victoryChibiAssets.keys) {
      final figure = VictoryFigure('test', role, 'Joueur', true);
      expect(assets, contains(figure.asset));
      expect(downloadablePackForAsset(figure.asset), 'victory-poses');
    }
    expect(pack['size'], greaterThan(0));
  });
  test('Only winners, final roles, survivors and eliminated allies', () {
    final figures = victoryFigures(
      {
        'winner': 'wolves',
        'winner_ids': ['a', 'b'],
        'alive_ids': ['a', 'c'],
        'revealed_roles': {'a': 'seer', 'b': 'werewolf', 'c': 'hunter'},
      },
      [
        {'id': 'a', 'nickname': 'Infectée'},
        {'id': 'b', 'nickname': 'Allié'},
        {'id': 'c', 'nickname': 'Adversaire'},
      ],
    );
    expect(figures.map((p) => p.id), ['a', 'b']);
    expect(figures.first.role, 'seer');
    expect(figures.first.survived, isTrue);
    expect(figures.last.survived, isFalse);
  });
  test('Left faces left, right faces right and centre is unchanged', () {
    expect(
      [for (var i = 0; i < 5; i++) mirrorVictoryFigure(i, 5)],
      [true, true, false, false, false],
    );
    expect(
      [for (var i = 0; i < 4; i++) mirrorVictoryFigure(i, 4)],
      [true, true, false, false],
    );
    expect(mirrorVictoryFigure(0, 1), isFalse);
  });
  test('Sisters appear once; draws have no victorious group', () {
    final figures = victoryFigures(
      {
        'winner': 'village',
        'winner_ids': ['a', 'b'],
        'alive_ids': ['a'],
        'revealed_roles': {'a': 'sisters', 'b': 'sisters'},
      },
      [
        {'id': 'a', 'nickname': 'A'},
        {'id': 'b', 'nickname': 'B'},
      ],
    );
    expect(figures, hasLength(1));
    expect(figures.single.name, 'A & B');
    expect(figures.single.survived, isTrue);
    expect(victoryFigures({'winner': 'draw'}, []), isEmpty);
    expect(victoryFigures({'winner': 'angel'}, []).single.survived, isNull);
  });
  testWidgets('Survivors are larger, foreground last, with per-row mirrors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (const bool.fromEnvironment('CAPTURE_CHIBIS')) {
      await tester.runAsync(() async {
        final data = await File(
          'assets/fonts/SourceSans3[wght].ttf',
        ).readAsBytes();
        await (FontLoader(
          'VillageSans',
        )..addFont(Future.value(ByteData.sublistView(data)))).load();
      });
    }
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF101923),
            textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'VillageSans',
            ),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                child: VictoryChibiGroup(
                  figures: [
                    VictoryFigure('dead', 'hunter', 'Allié', false),
                    VictoryFigure('left', 'villager', 'Gauche', true),
                    VictoryFigure('right', 'seer', 'Droite', true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final left = tester.widget<Transform>(
      find.byKey(const ValueKey('victory-facing-left')),
    );
    final right = tester.widget<Transform>(
      find.byKey(const ValueKey('victory-facing-right')),
    );
    expect(left.transform.storage[0], -1);
    expect(right.transform.storage[0], 1);
    final positions = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .toList();
    expect(positions.first.width, 108);
    expect(positions.last.width, 144);
    expect(positions.last.bottom, 0);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_CHIBIS')) {
      await tester.runAsync(() async {
        final context = tester.element(find.byType(VictoryChibiGroup));
        for (final id in ['chasseur', 'villageois', 'voyante']) {
          await precacheImage(
            AssetImage('assets/chibis/victory/$id-v1.png'),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '../../.tmp/chibis-victory-group.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
