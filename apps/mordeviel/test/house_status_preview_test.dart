import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/village/village_map.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'village_test.dart' as fixtures;

void main() {
  if (!const bool.fromEnvironment('CAPTURE_HOUSE_STATUS')) return;
  setUpAll(() async {
    for (final entry in {
      'VillageSans': 'assets/fonts/SourceSans3[wght].ttf',
      'Cormorant': 'assets/fonts/CormorantGaramond[wght].ttf',
      'MaterialIcons':
          'C:/bibliotheque/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await File(entry.value).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  for (final intense in [false, true]) {
    testWidgets('Aperçu ombres au sol $intense', (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final room = fixtures.room();
      room.remove('game');
      room['phase'] = 'lobby';
      room['visual_pack'] = intense ? 'intense' : 'classic';
      room['players'] = (room['players'] as List).take(6).toList();
      for (final player in room['players']) {
        player['ready'] = ['p0', 'p2', 'p4'].contains(player['id']);
      }
      final boundary = GlobalKey();
      Widget view() => RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: GameTheme.classic,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  VillageMap(
                    room: room,
                    selfId: 'p0',
                    displayHeight: 600,
                    animateGhosts: false,
                    onHouse: (_) {},
                    onChat: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.runAsync(() async {
        final context = tester.element(find.byType(VillageMap));
        for (final asset in [
          intense
              ? 'assets/village/intense/map_v3.png'
              : 'assets/village/map.jpg',
          for (final state in ['day', 'eliminated'])
            'assets/village/${intense ? 'intense/' : ''}house_$state.png',
        ]) {
          await precacheImage(AssetImage(asset), context);
        }
      });
      await tester.pump(const Duration(seconds: 1));
      for (final dead in [false, true]) {
        if (dead) {
          room['phase'] = 'day';
          room['game'] = {
            'alive_ids': ['p1', 'p2', 'p3', 'p5'],
          };
          await tester.pumpWidget(view());
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            'build/previews/house_status_${intense ? 'intense' : 'classic'}_${dead ? 'eliminated' : 'ready'}.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
}
