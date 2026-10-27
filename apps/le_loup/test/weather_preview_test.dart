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
  if (!const bool.fromEnvironment('CAPTURE_WEATHER')) return;
  setUpAll(() async {
    for (final entry in {
      'VillageSans': 'assets/fonts/SourceSans3[wght].ttf',
      'Cormorant': 'assets/fonts/CormorantGaramond[wght].ttf',
      'MaterialIcons':
          'C:/bibliotheque/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final data = await File(entry.value).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(data)))).load();
    }
  });
  testWidgets('Aperçus de la pluie et du jour suivant', (tester) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final rainy in [true, false]) {
      final room = fixtures.room(night: rainy);
      room['players'] = (room['players'] as List).take(8).toList();
      (room['game'] as Map)['alive_ids'] = [for (var i = 1; i < 8; i++) 'p$i'];
      (room['game'] as Map)['weather'] = {
        'kind': rainy ? 'storm' : 'clear',
        'rainbow': !rainy,
        'seed': 0,
        'night': 1,
        'elapsed_ms': rainy ? 4000 : 20000,
      };
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: GameTheme.classic,
            home: Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      rainy
                          ? 'La nuit sous l’orage'
                          : 'La lumière après la pluie',
                      style: const TextStyle(
                        fontFamily: 'Cormorant',
                        fontSize: 30,
                      ),
                    ),
                    const SizedBox(height: 20),
                    VillageMap(animateGhosts: false,
                      room: room,
                      displayHeight: 460,
                      onHouse: (_) {},
                      onChat: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(VillageMap));
        for (final asset in [
          'map.jpg',
          'house_day.png',
          'house_night.png',
          'house_eliminated.png',
        ]) {
          if (context.mounted) {
            await precacheImage(AssetImage('assets/village/$asset'), context);
          }
        }
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final picture =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/previews').create(recursive: true);
        await File(
          'build/previews/weather_${rainy ? 'storm' : 'rainbow'}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }
  });
}

