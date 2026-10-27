import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/village/village_map.dart';
import 'package:le_loup/village/village_chat.dart';
import 'package:le_loup/village/ceremonies.dart';
import 'package:le_loup/cards/card_gallery.dart';
import 'package:le_loup/cards/classic_role.dart';

Map<String, dynamic> room({bool night = false, bool disconnected = false}) => {
  'phase': night ? 'wolves' : 'day',
  'players': [
    for (var i = 0; i < 20; i++)
      {
        'id': 'p$i',
        'nickname': i == 0 ? 'Alice' : 'Joueur ${i + 1}',
        'connected': i != 0 || !disconnected,
        'house_slot': i,
      },
  ],
  'game': {
    'phase_revision': 3,
    'alive_ids': [for (var i = 0; i < 19; i++) 'p$i'],
    'chat_open': true,
    'day_messages': [],
  },
};

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_VILLAGE')) {
      for (final entry in {
        'Preview': 'C:/Windows/Fonts/arial.ttf',
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

  for (final size in [const Size(390, 844), const Size(1000, 700)]) {
    testWidgets('Village de 20 joueurs à $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      var selected = false;
      Widget build(Map<String, dynamic> state) => RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFFC79752),
            fontFamily: 'Preview',
          ),
          home: Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  VillageMap(
                    animateGhosts: false,
                    room: state,
                    selfId: 'p0',
                    bubbleAuthors: const {'p1'},
                    onHouse: (_) => selected = true,
                    onChat: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(room()));
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      expect(find.byType(HouseSprite), findsNWidgets(20));
      final oldLeft = tester
          .widget<Positioned>(find.byKey(const ValueKey('p0')))
          .left;
      await tester.tap(find.byType(HouseSprite).at(5));
      expect(selected, isTrue);
      await tester.pumpWidget(build(room(night: true, disconnected: true)));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Positioned>(find.byKey(const ValueKey('p0'))).left,
        oldLeft,
      );
      expect(
        tester
            .widgetList<HouseSprite>(find.byType(HouseSprite))
            .where((sprite) => sprite.state == 'eliminated')
            .length,
        1,
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_VILLAGE')) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/previews/village_${size.width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets('Un Villageois ne voit pas les messages de meute', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VillageChat(
            room: room(night: true),
            isHost: false,
            connected: true,
            privateState: {
              'role': 'villager',
              'alive': true,
              'messages': [
                {'author': 'p1', 'text': 'Secret meute'},
              ],
            },
            onSend: (action, revision, text) {},
          ),
        ),
      ),
    );
    expect(find.text('Secret meute'), findsNothing);
    expect(find.text('Envoyer'), findsNothing);
  });

  testWidgets('La roue reçoit le résultat serveur sans nouveau tirage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SentenceWheel(
              game: {
                'vote_result': {'eliminated': 'p0'},
                'sentence_options': [
                  'Guillotine',
                  'Pilori',
                  'Bannissement',
                  'Cachot',
                  'Échafaud',
                  'Exil',
                  'Jugement',
                  'Gibet',
                ],
                'sentence': {
                  'id': 'sentence-1',
                  'index': 3,
                  'label': 'Cachot',
                  'remaining_ms': 0,
                },
              },
              isHost: true,
              onSpin: () => fail('Aucun second tirage autorisé.'),
              name: (_) => 'Alice',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sentence : Cachot'), findsOneWidget);
    expect(find.text('Lancer la roue des sentences'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Une élimination secrète utilise le dos et la griffure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showElimination(context, name: 'Alice', cause: 'night'),
              child: const Text('Annonce'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Annonce'));
    await tester.pumpAndSettle();
    expect(
      find.text('Son rôle reste secret selon les règles du salon.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/village/claws.png',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Retourner au village'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Une carte privée commence face cachée puis révèle le rôle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RoleCardViewer(
          role: classicRoles[3],
          ambience: CardAmbience.classic,
          covered: true,
        ),
      ),
    );
    expect(find.text('Sorcière'), findsNothing);
    expect(find.text('Ma carte secrète'), findsOneWidget);
    await tester.tap(find.text('Découvrir ma carte'));
    await tester.pumpAndSettle();
    expect(find.text('Sorcière'), findsOneWidget);
    expect(find.text('Retourner la carte'), findsOneWidget);
    await tester.tap(find.text('Retourner la carte'));
    await tester.pumpAndSettle();
    expect(find.text('Camp : Village'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Le chat reste utilisable dans une petite fenêtre avec clavier', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 180,
              child: VillageChat(
                room: room(),
                privateState: {'id': 'p0', 'role': 'villager', 'alive': true},
                isHost: false,
                connected: true,
                onSend: (action, revision, text) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
