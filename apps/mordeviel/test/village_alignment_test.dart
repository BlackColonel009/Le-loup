import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/content/pack_store.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/village/village_map.dart';
import 'village_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  setUpAll(() async {
    support = await Directory.systemTemp.createTemp('wolf-village-alignment-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => support.path,
        );
    final folder = Directory(
      '${support.path}/content-packs/horror-village/1234567890abcdef',
    );
    await folder.create(recursive: true);
    final files = <Map<String, dynamic>>[];
    for (final name in [
      'map.png',
      'house_day.png',
      'house_night.png',
      'house_eliminated.png',
    ]) {
      final asset = 'assets/village/horror/$name';
      final data = await File(asset).readAsBytes();
      final hash = sha256.convert(data).toString();
      await File('${folder.path}/$hash').writeAsBytes(data);
      files.add({
        'asset': asset,
        'size': data.length,
        'sha256': hash,
        'url': '/content/packs/horror-village/1234567890abcdef/$hash',
      });
    }
    await File('${support.path}/content-packs/catalog.json').writeAsString(
      jsonEncode({
        'packs': [
          {
            'id': 'horror-village',
            'title': 'Horreur',
            'version': '1234567890abcdef',
            'size': files.fold<int>(0, (n, f) => n + (f['size'] as int)),
            'files': files,
          },
        ],
      }),
    );
    await PackStore.instance.initialize();
    if (const bool.fromEnvironment('CAPTURE_ALIGNMENT')) {
      for (final e in {
        'VillageSans': 'assets/fonts/SourceSans3[wght].ttf',
        'MaterialIcons':
            'C:/bibliotheque/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final data = await File(e.value).readAsBytes();
        await (FontLoader(
          e.key,
        )..addFont(Future.value(ByteData.sublistView(data)))).load();
      }
    }
  });
  tearDownAll(() async {
    PaintingBinding.instance.imageCache.clear();
    await support.delete(recursive: true);
  });
  test('Les 20 maisons Horreur restent sur les quatre rangées du terrain', () {
    expect(horrorVillagePlots, hasLength(20));
    final bounds = Offset.zero & intenseVillageCanvasSize;
    final boxes = [
      for (final p in horrorVillagePlots)
        Rect.fromLTWH(
          p.dx * bounds.width - 98,
          p.dy * bounds.height - 190,
          196,
          218,
        ),
    ];
    expect(horrorVillagePlots.map((p) => p.dy).toSet(), hasLength(4));
    for (var i = 0; i < boxes.length; i++) {
      expect(bounds.contains(boxes[i].topLeft), isTrue);
      expect(bounds.contains(boxes[i].bottomRight), isTrue);
      for (var j = i + 1; j < boxes.length; j++) {
        expect(
          boxes[i].overlaps(boxes[j]),
          isFalse,
          reason: 'Maisons $i et $j',
        );
      }
    }
  });
  for (final theme in ['classic', 'intense', 'horror']) {
    for (final size in [const Size(390, 844), const Size(1440, 1050)]) {
      testWidgets('Ancrage stable jour/nuit/éliminé · $theme · $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = fixtures.room()..['visual_pack'] = theme;
        (state['game'] as Map)['alive_ids'] = [
          for (var i = 0; i < 20; i++) 'p$i',
        ];
        final boundary = GlobalKey();
        Widget scene() => RepaintBoundary(
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
                      room: state,
                      displayHeight: size.height - 120,
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
        // Preload file-backed packs before their first resolution inside the
        // widget fake clock, so cached image decoding remains deterministic.
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(Scaffold));
          for (final name in [
            'map',
            'house_day',
            'house_night',
            'house_eliminated',
          ]) {
            final asset = theme == 'horror'
                ? 'assets/village/horror/$name.png'
                : theme == 'intense'
                ? 'assets/village/intense/${name == 'map' ? 'map_v3' : name}.png'
                : 'assets/village/$name.${name == 'map' ? 'jpg' : 'png'}';
            final path = PackStore.instance.pathFor(asset);
            await precacheImage(
              path == null
                  ? AssetImage(asset)
                  : FileImage(File(path)) as ImageProvider,
              context,
            );
          }
        });
        await tester.pumpWidget(scene());
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Vue d’ensemble'));
        await tester.pumpAndSettle();
        final first = tester.widget<Positioned>(
          find.byKey(const ValueKey('p0')),
        );
        expect(find.byType(HouseSprite), findsNWidgets(20));
        if (const bool.fromEnvironment('CAPTURE_ALIGNMENT') &&
            size.width > 1000) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('../../.tmp').create(recursive: true);
            await File(
              '../../.tmp/village-alignment-$theme.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        for (final phase in ['wolves', 'day']) {
          state['phase'] = phase;
          (state['game'] as Map)['is_night'] = phase == 'wolves';
          if (phase == 'day') {
            (state['game'] as Map)['alive_ids'] = [
              for (var i = 1; i < 20; i++) 'p$i',
            ];
          }
          await tester.pumpWidget(scene());
          await tester.pumpAndSettle();
          final next = tester.widget<Positioned>(
            find.byKey(const ValueKey('p0')),
          );
          expect(next.left, first.left);
          expect(next.top, first.top);
          expect(next.width, first.width);
          expect(next.height, first.height);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
