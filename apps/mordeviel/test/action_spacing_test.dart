import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_host/local_host.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/night_panel.dart';
import 'package:mordeviel/community/community_screen.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_ACTION_SPACING')) {
      for (final e in {
        'Cormorant': 'assets/fonts/CormorantGaramond[wght].ttf',
        'VillageSans': 'assets/fonts/SourceSans3[wght].ttf',
      }.entries) {
        final b = await File(e.value).readAsBytes();
        await (FontLoader(
          e.key,
        )..addFont(Future.value(ByteData.sublistView(b)))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('Actions espacées à $size avec texte $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final g = NightGame(
          {'g': 'guardian', 'w': 'werewolf', 'a': 'villager', 'b': 'villager'},
          editions: {'g': 'horror'},
        );
        g.startNight();
        g.callNight('guardian');
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: GameTheme.classic,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('Les actions de la nuit')),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: NightPanel(
                    room: {
                      'players': [
                        for (final id in g.roles.keys)
                          {'id': id, 'nickname': id.toUpperCase()},
                      ],
                      'game': g.publicState,
                    },
                    privateState: g.privateState('g'),
                    isHost: false,
                    connected: true,
                    onStart: (_) {},
                    onAdvance: () {},
                    onPause: () {},
                    onResume: () {},
                    onAction:
                        (
                          action,
                          revision, {
                          target,
                          save,
                          kill,
                          text,
                          targets,
                        }) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final primary = find.widgetWithText(FilledButton, 'Protéger un joueur');
        final secondary = find.widgetWithText(TextButton, 'Passer mon action');
        await tester.ensureVisible(primary);
        await tester.pumpAndSettle();
        expect(tester.getSize(primary).height, greaterThanOrEqualTo(48));
        expect(
          tester.getTopLeft(secondary).dy - tester.getBottomLeft(primary).dy,
          greaterThanOrEqualTo(12),
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_ACTION_SPACING') &&
            size.width == 390 &&
            scale == 1) {
          await tester.runAsync(() async {
            final img =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '../../.tmp/action-spacing.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('La connexion sépare ses boutons d’au moins douze pixels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: GameTheme.classic, home: const CommunityScreen()),
    );
    await tester.pumpAndSettle();
    final existing = find.widgetWithText(TextButton, 'J’ai déjà un compte');
    await tester.scrollUntilVisible(
      existing,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(existing);
    await tester.pumpAndSettle();
    await tester.tap(existing);
    await tester.pumpAndSettle();
    final login = find.widgetWithText(FilledButton, 'Me connecter');
    final create = find.widgetWithText(TextButton, 'Créer un compte');
    await tester.ensureVisible(login);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(create).dy - tester.getBottomLeft(login).dy,
      greaterThanOrEqualTo(12),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
