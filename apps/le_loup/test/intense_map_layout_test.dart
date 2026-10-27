import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/design/game_theme.dart';
import 'package:le_loup/village/village_map.dart';
import 'village_test.dart' as fixtures;

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_INTENSE_MAP')) return;
    for (final entry in {
      'Cormorant': 'assets/fonts/CormorantGaramond[wght].ttf',
      'VillageSans': 'assets/fonts/SourceSans3[wght].ttf',
      'MaterialIcons':
          'C:/bibliotheque/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final data = await File(entry.value).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(data)))).load();
    }
  });

  test('Vingt maisons Intense et leurs noms tiennent sans chevauchement', () {
    final bounds = Offset.zero & intenseVillageCanvasSize;
    final houses = [
      for (final plot in intenseVillagePlots)
        Rect.fromLTWH(
          plot.dx * bounds.width - 130,
          plot.dy * bounds.height - 236,
          260,
          272,
        ),
    ];
    expect(houses, hasLength(20));
    for (var i = 0; i < houses.length; i++) {
      expect(bounds.contains(houses[i].topLeft), isTrue);
      expect(bounds.contains(houses[i].bottomRight), isTrue);
      for (var j = i + 1; j < houses.length; j++) {
        expect(
          houses[i].overlaps(houses[j]),
          isFalse,
          reason: 'Maisons $i et $j',
        );
      }
    }
  });

  for (final size in [const Size(1440, 1000), const Size(390, 844)]) {
    testWidgets('Village Intense complet, panorama et zoom à $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = fixtures.room()..['visual_pack'] = 'intense';
      final boundary = GlobalKey();
      var selected = false;
      Widget scene() => RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: GameTheme.classic,
          home: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  VillageMap(
                    room: state,
                    selfId: 'p0',
                    displayHeight: size.height - 115,
                    animateGhosts: false,
                    onHouse: (_) => selected = true,
                    onChat: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene());
      await tester.runAsync(() async {
        final context = tester.element(find.byType(VillageMap));
        for (final asset in [
          'map_v3.png',
          'house_day.png',
          'house_night.png',
          'house_eliminated.png',
        ]) {
          await precacheImage(
            AssetImage('assets/village/intense/$asset'),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      expect(find.byType(HouseSprite), findsNWidgets(20));
      expect(find.text('Village Intense Premium'), findsOneWidget);
      final first = tester.widget<Positioned>(find.byKey(const ValueKey('p0')));
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      if (size.width < 600) {
        await tester.tap(find.byType(HouseSprite).first);
        expect(selected, isTrue);
      }
      await tester.tap(find.byTooltip('Vue d’ensemble'));
      await tester.pumpAndSettle();
      final overview = viewer.transformationController!.value
          .getMaxScaleOnAxis();
      await tester.tap(find.byTooltip('Agrandir le village'));
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(overview),
      );
      await tester.tap(find.byTooltip('Vue d’ensemble'));
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('CAPTURE_INTENSE_MAP')) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/previews').create(recursive: true);
          await File(
            'build/previews/intense_map_${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      (state['game'] as Map)['is_night'] = true;
      await tester.pumpWidget(scene());
      await tester.pumpAndSettle();
      expect(
        tester.widget<Positioned>(find.byKey(const ValueKey('p0'))).left,
        first.left,
      );
      state['visual_pack'] = 'classic';
      await tester.pumpWidget(scene());
      await tester.pumpAndSettle();
      final classic = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect((classic.child as SizedBox).width, classicVillageCanvasSize.width);
      expect(find.text('Village classique'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
