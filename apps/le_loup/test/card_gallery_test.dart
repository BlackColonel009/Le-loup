import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/cards/card_gallery.dart';
import 'package:le_loup/cards/classic_role.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_CARDS')) {
      final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
      await (FontLoader(
        'Preview',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('Retourner et cacher une carte à $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'Preview',
              ),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showRoleCard(context, classicRoles[3]),
                    child: const Text('Ouvrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.text('Ouvrir'));
        await precacheImage(AssetImage(classicRoles[3].asset), context);
        if (context.mounted) {
          await precacheImage(
            const AssetImage('assets/frames/classic.jpg'),
            context,
          );
        }
      });
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Retourner la carte'), findsOneWidget);
      await tester.tap(find.text('Retourner la carte'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(RoleCardViewer), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Camp : Village'), findsOneWidget);
      expect(find.text(classicRoles[3].summary), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_CARDS')) {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('build/previews/card_${size.width.toInt()}.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Voir l’illustration'));
      await tester.pumpAndSettle();
      expect(find.text('Camp : Village'), findsNothing);
      await tester.tap(find.text('Cacher la carte'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(RoleCardViewer), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(RoleCardViewer), findsNothing);
      expect(find.text('Ouvrir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Les règles restent lisibles avec un texte agrandi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const RoleCardViewer(
          role: ClassicRole(
            'hunter',
            'Chasseur',
            'Village',
            'À votre mort',
            'Résumé',
            'Précisions',
          ),
          ambience: CardAmbience.horror,
        ),
      ),
    );
    await tester.tap(find.text('Retourner la carte'));
    await tester.pumpAndSettle();
    expect(find.text('Résumé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
