import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/profile/avatar_gallery.dart';
import 'package:mordeviel/profile/player_avatar.dart';
import 'package:mordeviel/profile/profile_photo.dart';
import 'package:mordeviel/content/pack_store.dart';
import 'package:mordeviel/community/community_conversation.dart';
import 'package:mordeviel/village/owl_flight.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  setUpAll(() async {
    support = await Directory.systemTemp.createTemp('wolf-avatar-tests-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => support.path,
        );
    final folder = Directory(
      '${support.path}/content-packs/avatars-classic/1234567890abcdef',
    );
    await folder.create(recursive: true);
    final files = <Map<String, dynamic>>[];
    for (final a in avatarCatalog) {
      final asset = a['asset'] as String;
      final bytes = await File(
        'assets/cards/${asset.split('/').last}',
      ).readAsBytes();
      final hash = sha256.convert(bytes).toString();
      await File('${folder.path}/$hash').writeAsBytes(bytes);
      files.add({
        'asset': asset,
        'size': bytes.length,
        'sha256': hash,
        'url': '/content/packs/avatars-classic/1234567890abcdef/$hash',
      });
    }
    await File('${support.path}/content-packs/catalog.json').writeAsString(
      jsonEncode({
        'packs': [
          {
            'id': 'avatars-classic',
            'title': 'Avatars',
            'version': '1234567890abcdef',
            'size': files.fold<int>(0, (n, f) => n + (f['size'] as int)),
            'files': files,
          },
        ],
      }),
    );
    await PackStore.instance.initialize();
  });
  tearDownAll(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      await support.delete(recursive: true);
    } on FileSystemException {
      /* Windows can release an in-flight decoder after the test process exits. */
    }
  });
  test(
    '20 visages téléchargeables, quatre disponibles, zones cadrées valides',
    () {
      expect(avatarCatalog.length, 20);
      expect(avatarCatalog.where((a) => a['starter'] == true).length, 4);
      expect(PackStore.instance.installed('avatars-classic'), isTrue);
      for (final avatar in avatarCatalog) {
        final crop = (avatar['crop'] as List).cast<num>();
        expect(crop[0], greaterThanOrEqualTo(0));
        expect(crop[1], greaterThanOrEqualTo(0));
        expect(crop[0] + crop[2], lessThanOrEqualTo(1));
        expect(crop[1] + crop[3], lessThanOrEqualTo(1));
      }
      expect(
        File('pubspec.yaml').readAsStringSync(),
        isNot(contains('    - assets/avatars/')),
      );
    },
  );
  testWidgets(
    'Les défis ne se contournent pas et un portrait disponible peut être enregistré',
    (tester) async {
      final chosen = <String>[];
      Future<Map<String, dynamic>> request(
        String path, {
        String method = 'GET',
        Map<String, dynamic>? body,
      }) async {
        if (method == 'PUT') {
          chosen.add(body!['avatar_id'] as String);
          return {
            'avatar': {'id': body['avatar_id'], 'kind': 'game'},
          };
        }
        return {
          'avatar': {'id': 'classic-villager', 'kind': 'game'},
          'avatars': [
            for (final a in avatarCatalog)
              {...a, 'locked': a['starter'] != true},
          ],
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AvatarGalleryScreen(request: request),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Chasseur'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chasseur'));
      await tester.pump();
      expect(chosen, isEmpty);
      expect(find.textContaining('Ce visage se débloquera'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Voyante'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voyante'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(chosen, ['classic-seer']);
      expect(find.text('Ouvrir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Le conseil communautaire garde le clavier et ouvre le bon profil',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      int? visited, reported;
      var sends = 0;
      Widget scene() => MaterialApp(
        home: Scaffold(
          body: CommunityConversation(
            messages: [
              {
                'id': 1,
                'user_id': 7,
                'nickname': 'Luna',
                'role': 'player',
                'text': 'Qui veut jouer ce soir ?',
                'created': 1793610000,
                'avatar': {'id': 'classic-seer', 'kind': 'game'},
              },
            ],
            controller: controller,
            userId: 8,
            onSend: () => sends++,
            onSticker: () {},
            onProfile: (id) => visited = id,
            onReport: (id) => reported = id,
          ),
        ),
      );
      await tester.pumpWidget(scene());
      await tester.pump();
      await tester.tap(find.text('Luna'));
      expect(visited, 7);
      await tester.tap(find.byTooltip('Options du message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler ce message'));
      await tester.pumpAndSettle();
      expect(reported, 1);
      await tester.enterText(
        find.byKey(const ValueKey('community-chat-input')),
        'Présent !',
      );
      final before = tester.widget<TextField>(find.byType(TextField)).focusNode;
      await tester.pumpWidget(scene());
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode,
        same(before),
      );
      expect(before!.hasFocus, isTrue);
      expect(controller.text, 'Présent !');
      await tester.tap(find.byTooltip('Envoyer'));
      expect(sends, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Le hibou reste visible malgré une caméra éloignée', (
    tester,
  ) async {
    final camera = TransformationController(
      Matrix4.identity()
        ..translateByDouble(-3000, -2000, 0, 1)
        ..scaleByDouble(.2, .2, 1, 1),
    );
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 300,
            child: OwlFlight(
              seconds: 0,
              camera: camera,
              world: const Size(3072, 2048),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final owl = tester.getRect(find.byKey(const ValueKey('owl-perched')));
    final viewport = tester.getRect(find.byType(OwlFlight));
    expect(viewport.contains(owl.topLeft), isTrue);
    expect(viewport.contains(owl.bottomRight), isTrue);
    expect(owl.width, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });
  testWidgets('La photo envoyée est un carré léger', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 60, 120),
        ui.Paint()..color = const Color(0xFF996644),
      );
      final picture = recorder.endRecording();
      final source = await picture.toImage(60, 120);
      // The source picture is generated in memory; no personal file is read.
      final raw = await source.toByteData(format: ui.ImageByteFormat.png);
      final bytes = await prepareProfilePhoto(raw!.buffer.asUint8List());
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 384);
      expect(image.height, 384);
      expect(bytes.length, lessThan(600000));
      image.dispose();
      codec.dispose();
      source.dispose();
      picture.dispose();
    });
  });
}
