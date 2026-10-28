import 'dart:io';
import 'package:mordeviel/main.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/village/village_navigation.dart';
import 'package:mordeviel/village/village_map.dart';
import 'package:mordeviel/village/village_chat.dart';

void main() {
  if (!const bool.fromEnvironment('CAPTURE_NAVIGATION')) return;
  setUpAll(() async {
    for (final entry in {
      'Preview': 'C:/Windows/Fonts/arial.ttf',
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
  });
  testWidgets('Aperçus de la navigation classique', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final room = <String, dynamic>{
      'phase': 'day',
      'players': [
        for (var i = 0; i < 8; i++)
          {
            'id': 'p$i',
            'nickname': [
              'Alice',
              'Hugo',
              'Lina',
              'Noé',
              'Jade',
              'Lou',
              'Adam',
              'Rose',
            ][i],
            'house_slot': i,
            'connected': true,
          },
      ],
      'game': {
        'phase_revision': 3,
        'alive_ids': [for (var i = 0; i < 8; i++) 'p$i'],
        'chat_open': true,
        'day_messages': [
          {'author': 'p0', 'text': 'Qui a entendu quelque chose cette nuit ?'},
          {
            'author': 'p1',
            'text': 'Je propose qu’on écoute chacun avant de voter.',
          },
        ],
      },
    };
    final boundary = GlobalKey();
    for (final destination in [
      VillageDestination.village,
      VillageDestination.council,
    ]) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: GameTheme.classic,
            home: Scaffold(
              body: VillageNavigation(
                destination: destination,
                phase: 'day',
                isHost: false,
                code: '483921',
                onSelect: (_) {},
                onCodex: () {},
                village: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    VillageMap(animateGhosts: false,
                      displayHeight: 480,
                      room: room,
                      selfId: 'p0',
                      onHouse: (_) {},
                      onChat: () {},
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Le conseil vous attend',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Rejoindre le conseil'),
                    ),
                  ],
                ),
                actions: const Text('Réunion et vote'),
                preparation: const SizedBox(),
                chat: VillageChat(
                  room: room,
                  privateState: const {'alive': true},
                  isHost: false,
                  connected: true,
                  fullPage: true,
                  onSend: (_, _, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(VillageNavigation));
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
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/previews').create(recursive: true);
        await File(
          'build/previews/navigation_${destination.name}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(
      RepaintBoundary(key: boundary, child: const MordevielApp()),
    );
    await tester.pump();
    await tester.tap(find.text('Passer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(WelcomeScreen));
      if (context.mounted) {
        await precacheImage(
          const AssetImage('assets/backgrounds/portrait.jpg'),
          context,
        );
        await precacheImage(
          const AssetImage('assets/branding/logo.png'),
          context,
        );
      }
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/previews/classic_home.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}

