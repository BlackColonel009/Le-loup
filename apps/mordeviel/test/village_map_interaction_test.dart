import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/village/village_map.dart';
import 'village_test.dart' as fixtures;

void main() {
  for (final theme in ['classic', 'intense', 'horror']) {
    testWidgets('Pincement depuis la vue globale sans saut · $theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final room = fixtures.room()..['visual_pack'] = theme;
      await tester.pumpWidget(_scene(room));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Vue d’ensemble'));
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final controller = viewer.transformationController!;
      final before = controller.value.getMaxScaleOnAxis();
      final center = tester.getRect(find.byType(InteractiveViewer)).center;
      final a = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 101,
      );
      final b = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 102,
      );
      await tester.pump(const Duration(milliseconds: 20));
      for (var i = 1; i <= 4; i++) {
        await a.moveTo(center - Offset(40 + i * 5, 0));
        await b.moveTo(center + Offset(40 + i * 5, 0));
        await tester.pump(const Duration(milliseconds: 20));
      }
      final after = controller.value.getMaxScaleOnAxis();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(after, greaterThan(before));
      expect(after, lessThan(before * 1.9), reason: 'Pas de zoom forcé');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Zoom progressif et quatre bords accessibles · $theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_scene(fixtures.room()..['visual_pack'] = theme));
      await tester.pumpAndSettle();
      var viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final initial = viewer.transformationController!.value.entry(0, 0);
      await tester.tap(find.byTooltip('Agrandir le village'));
      await tester.pumpAndSettle();
      final zoomed = viewer.transformationController!.value.entry(0, 0);
      expect(zoomed, closeTo(initial * 1.5, .0001));
      await tester.tap(find.byTooltip('Agrandir le village'));
      await tester.pumpAndSettle();
      for (final direction in [
        const Offset(1, 1),
        const Offset(-1, 1),
        const Offset(-1, -1),
        const Offset(1, -1),
      ]) {
        await tester.timedDragFrom(
          tester.getRect(find.byType(InteractiveViewer)).center,
          direction * 5000,
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();
        viewer = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        final matrix = viewer.transformationController!.value;
        final world = viewer.child as SizedBox;
        final viewport = tester.getSize(find.byType(InteractiveViewer));
        final scale = matrix.getMaxScaleOnAxis();
        expect(matrix.storage.every((v) => v.isFinite), isTrue);
        expect(
          matrix.entry(0, 3),
          closeTo(
            direction.dx > 0 ? 0 : viewport.width - world.width! * scale,
            .01,
          ),
        );
        expect(
          matrix.entry(1, 3),
          closeTo(
            direction.dy > 0 ? 0 : viewport.height - world.height! * scale,
            .01,
          ),
        );
      }
      await tester.tap(find.byTooltip('Vue d’ensemble'));
      await tester.pumpAndSettle();
      viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      expect(
        viewer.transformationController!.value.entry(0, 0),
        closeTo(viewer.minScale, .0001),
      );
      await tester.timedDragFrom(
        tester.getRect(find.byType(InteractiveViewer)).center,
        const Offset(40, 40),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.entry(0, 0),
        closeTo(viewer.minScale, .0001),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rotation conserve le lieu observé · $theme', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final room = fixtures.room()..['visual_pack'] = theme;
      await tester.pumpWidget(_scene(room));
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final controller = viewer.transformationController!;
      await tester.tap(find.byTooltip('Agrandir le village'));
      await tester.tap(find.byTooltip('Agrandir le village'));
      await tester.pumpAndSettle();
      // Déplacement réel vers une zone différente du centre du village.
      final box = tester.getRect(find.byType(InteractiveViewer));
      await tester.timedDragFrom(
        box.center,
        const Offset(-100, -50),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      final oldSize = tester.getSize(find.byType(InteractiveViewer));
      final focus = controller.toScene(oldSize.center(Offset.zero));
      final oldZoom = controller.value.getMaxScaleOnAxis();

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      final newViewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final newSize = tester.getSize(find.byType(InteractiveViewer));
      final nextFocus = newViewer.transformationController!.toScene(
        newSize.center(Offset.zero),
      );
      expect((nextFocus - focus).distance, lessThan(2));
      expect(
        newViewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(newViewer.minScale),
        reason: 'La rotation ne remet pas le zoom à zéro ($oldZoom)',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Deux doigts annulés libèrent le défilement de la page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_scene(fixtures.room()));
    await tester.pumpAndSettle();
    final center = tester.getRect(find.byType(InteractiveViewer)).center;
    final first = await tester.startGesture(center, pointer: 201);
    final second = await tester.startGesture(
      center + const Offset(50, 0),
      pointer: 202,
    );
    await tester.pump();
    await first.cancel();
    await tester.pump();
    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    await second.cancel();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListView>(find.byType(ListView))
          .physics!
          .allowUserScrolling,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Un rafraîchissement du salon conserve la caméra et la sélection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final room = fixtures.room();
      room['players'] = (room['players'] as List).take(2).toList();
      var selected = '';
      Widget scene() =>
          _scene(room, onHouse: (player) => selected = player['id'] as String);
      await tester.pumpWidget(scene());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Agrandir le village'));
      await tester.pumpAndSettle();
      final before = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value
          .clone();
      (room['game'] as Map)['is_night'] = true;
      await tester.pumpWidget(scene());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value,
        before,
      );
      await tester.tap(find.byTooltip('Vue d’ensemble'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(HouseSprite).first);
      await tester.pumpAndSettle();
      expect(selected, 'p0');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Glisser le village ne sélectionne pas et ne défile pas la page',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var selections = 0;
      await tester.pumpWidget(
        _scene(fixtures.room(), scroll: scroll, onHouse: (_) => selections++),
      );
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final before = viewer.transformationController!.value.clone();
      final center = tester.getRect(find.byType(InteractiveViewer)).center;
      await tester.timedDragFrom(
        center,
        const Offset(0, -80),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(selections, 0);
      expect(viewer.transformationController!.value, isNot(before));
      // Le défilement normal revient dès que les doigts quittent la carte.
      await tester.timedDragFrom(
        const Offset(190, 800),
        const Offset(0, -60),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _scene(
  Map<String, dynamic> room, {
  ScrollController? scroll,
  ValueChanged<Map<String, dynamic>>? onHouse,
}) => _MapScene(room: room, scroll: scroll, onHouse: onHouse);

class _MapScene extends StatefulWidget {
  const _MapScene({required this.room, this.scroll, this.onHouse});
  final Map<String, dynamic> room;
  final ScrollController? scroll;
  final ValueChanged<Map<String, dynamic>>? onHouse;
  @override
  State<_MapScene> createState() => _MapSceneState();
}

class _MapSceneState extends State<_MapScene> {
  bool _mapPointerActive = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: LayoutBuilder(
        builder: (context, size) => ListView(
          controller: widget.scroll,
          physics: _mapPointerActive
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: const EdgeInsets.all(16),
          children: [
            VillageMap(
              room: widget.room,
              displayHeight: size.maxHeight * .72,
              animateGhosts: false,
              onHouse: widget.onHouse ?? (_) {},
              onChat: () {},
              onPointerActivity: (active) {
                if (mounted) setState(() => _mapPointerActive = active);
              },
            ),
            const SizedBox(height: 700),
          ],
        ),
      ),
    ),
  );
}
