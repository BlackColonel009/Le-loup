import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/cards/classic_role.dart';
import 'package:mordeviel/cards/card_gallery.dart';
import 'package:mordeviel/village/village_map.dart';
import 'package:mordeviel/village/horror_ambience.dart';
import 'package:mordeviel/content/content_image.dart';

void main() {
  test('Chaque carte possède ses trois illustrations, sans rôle manquant', () {
    final cards = [...collectionCards, configuredRole('villager', feminine: true)];
    expect(cards.length, 20);
    for (final role in cards) {
      final id = role.feminine ? 'villager_female' : role.id;
      expect(File(role.asset).existsSync(), true, reason: 'Classique : $id');
      final intense = id == 'villager_female'
          ? 'assets/cards/intense/villager_female.png'
          : 'assets/cards/intense/${id}_intense.${['mayor', 'sisters', 'scapegoat'].contains(id) ? 'png' : 'jpg'}';
      expect(File(intense).existsSync(), true, reason: 'Intense : $id');
      expect(
        File('assets/cards/horror/$id.png').existsSync(),
        true,
        reason: 'Horreur : $id',
      );
    }
  });
  testWidgets(
    'La nuit Horreur déroule brume, chauves-souris et vol du hibou sans bloquer les gestes',
    (tester) async {
      HorrorPreferences.instance.scares = true;
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 640,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TextButton(
                    onPressed: () => taps++,
                    child: const Text('Maison'),
                  ),
                  const HorrorAmbience(night: true, seed: 0),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 22));
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.tap(find.text('Maison'));
      expect(taps, 1);
      await tester.pump(const Duration(seconds: 118));
      expect(
        tester
            .widgetList<ContentImage>(find.byType(ContentImage))
            .any((i) => i.asset.endsWith('owl_perched.png')),
        true,
      );
      await tester.pump(const Duration(seconds: 8));
      expect(
        tester
            .widgetList<ContentImage>(find.byType(ContentImage))
            .any((i) => i.asset.endsWith('/owl.png')),
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 7));
      expect(find.byType(ContentImage), findsNothing);
      await tester.pumpWidget(
        const MaterialApp(
          home: HorrorAmbience(night: true, seed: 0, paused: true),
        ),
      );
      expect(find.byType(ContentImage), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'Le Maire est consultable dans chaque thème sans devenir un rôle secret',
    () {
      expect(configuredRole('mayor'), mayorOffice);
      expect(classicRoles.any((r) => r.id == 'mayor'), false);
      expect(collectionCards.any((r) => r.id == 'mayor'), true);
      expect(RoleCardFront.hasIntense('mayor'), true);
    },
  );
  test('Les huit sentences Horreur sont les fichiers utilisateur intacts', () {
    const files = {
      'guillotine': 'Guillotine_horreur.jpg',
      'pilori': 'pilori_horreur.jpg',
      'bannissement': 'Bannissement_horreur.jpg',
      'cachot': 'cachot_horreur.jpg',
      'echafaud': 'echafaud_horreur.jpg',
      'exil': 'exil_horreur.jpg',
      'jugement': 'jugement.jpg',
      'gibet': 'Gibet_horreur.jpg',
    };
    for (final e in files.entries) {
      expect(
        sha256
            .convert(
              File(
                'assets/village/horror/sentences/${e.key}.jpg',
              ).readAsBytesSync(),
            )
            .toString(),
        sha256
            .convert(
              File(
                '../../mordeviel/sentances types/sentence_horreur/${e.value}',
              ).readAsBytesSync(),
            )
            .toString(),
      );
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('    - assets/stickers/')));
    expect(pubspec, isNot(contains('    - assets/cards/horror/')));
    expect(
      pubspec,
      isNot(contains('    - assets/audio/classic/neural/ghost/mdj_')),
    );
  });
  test(
    'Les packs publiés contiennent les cartes, les sons et leurs empreintes',
    () {
      final data =
          jsonDecode(
                File('../../shared/content/catalog.json').readAsStringSync(),
              )
              as Map;
      final packs = data['packs'] as List;
      expect(packs.length, 12);
      for (final id in [
        'horror-cards',
        'horror-village',
        'horror-ambience',
        'stickers-classic',
      ]) {
        expect(packs.any((p) => p['id'] == id), true);
      }
    },
  );
  for (final size in [const Size(360, 740), const Size(900, 420)]) {
    testWidgets(
      'Village Horreur : vingt maisons et frayeurs désactivées à $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        HorrorPreferences.instance.scares = false;
        final players = [
          for (var i = 0; i < 20; i++)
            {
              'id': 'p$i',
              'nickname': 'Joueur $i',
              'house_slot': i,
              'connected': true,
            },
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: VillageMap(
                  room: {
                    'visual_pack': 'horror',
                    'phase': 'day',
                    'players': players,
                    'game': {
                      'is_night': false,
                      'mayor': 'p0',
                      'alive_ids': players.map((p) => p['id']).toList(),
                    },
                  },
                  onHouse: (_) {},
                  onChat: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HouseSprite), findsNWidgets(20));
        expect(
          tester
              .widgetList<HouseSprite>(find.byType(HouseSprite))
              .every((h) => h.horror),
          true,
        );
        expect(find.text('Village Horreur'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        HorrorPreferences.instance.scares = true;
      },
    );
  }
}
