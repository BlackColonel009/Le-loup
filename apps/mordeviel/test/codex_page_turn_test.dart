import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/cards/codex_page_turn.dart';

void main() {
  test(
    'Une feuille garde sa reliure et passe réellement du côté droit au côté gauche',
    () {
      const size = Size(808, 520);
      final start = codexCurlPoint(
        size: size,
        doublePage: true,
        forward: true,
        progress: 0,
        u: 1,
        v: .5,
      );
      final end = codexCurlPoint(
        size: size,
        doublePage: true,
        forward: true,
        progress: 1,
        u: 1,
        v: .5,
      );
      expect(start.position.dx, closeTo(808, .001));
      expect(end.position.dx, closeTo(0, .001));
      final inner = codexCurlPoint(
        size: size,
        doublePage: true,
        forward: true,
        progress: .5,
        u: 0,
        v: .5,
      );
      final front = codexCurlPoint(
        size: size,
        doublePage: true,
        forward: true,
        progress: .5,
        u: .25,
        v: .5,
      );
      final back = codexCurlPoint(
        size: size,
        doublePage: true,
        forward: true,
        progress: .5,
        u: .75,
        v: .5,
      );
      expect(inner.position.dx, closeTo(404, .001));
      expect(math.cos(front.angle), greaterThan(0));
      expect(math.cos(back.angle), lessThan(0));
      expect(front.position.dx, greaterThan(inner.position.dx));
    },
  );

  for (final two in [false, true]) {
    testWidgets(
      'Le doigt plie la feuille, puis le recto/verso se repose, double page : $two',
      (tester) async {
        tester.view.physicalSize = two
            ? const Size(844, 500)
            : const Size(390, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var index = 0;
        final changes = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: CodexPageTurn(
                    index: index,
                    count: 4,
                    doublePage: two,
                    layoutToken: two,
                    pageBuilder: (leaf, left) => ColoredBox(
                      color: left
                          ? const Color(0xFFE4CAA0)
                          : const Color(0xFFF3E5C5),
                      child: Center(child: Text('Feuille $leaf')),
                    ),
                    onChanged: (next) => update(() {
                      index = next;
                      changes.add(next);
                    }),
                  ),
                ),
              ),
            ),
          ),
        );
        final book = find.byType(CodexPageTurn);
        final box = tester.getRect(book);
        final leafWidth = two ? (box.width - 8) / 2 : box.width;
        final finger = await tester.startGesture(
          Offset(box.right - 12, box.center.dy + 60),
        );
        await finger.moveBy(const Offset(-20, 0));
        await tester.pump();
        await finger.moveBy(Offset(-leafWidth * .56, 0));
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('codex-curled-sheet')),
          findsOneWidget,
        );
        expect(changes, isEmpty);
        await finger.up();
        await tester.pumpAndSettle();
        expect(index, 1);
        expect(changes, [1]);
        expect(find.byKey(const ValueKey('codex-curled-sheet')), findsNothing);
        final back = await tester.startGesture(
          Offset(box.left + 12, box.center.dy - 50),
        );
        await back.moveBy(const Offset(20, 0));
        await tester.pump();
        await back.moveBy(Offset(leafWidth * .56, 0));
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('codex-curled-sheet')),
          findsOneWidget,
        );
        await back.up();
        await tester.pumpAndSettle();
        expect(index, 0);
        expect(changes, [1, 0]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Une petite prise revient en place et les mouvements réduits ne capturent aucune texture',
    (tester) async {
      final key = GlobalKey<CodexPageTurnState>();
      var index = 0;
      Widget scene(bool reduced) => MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: CodexPageTurn(
              key: key,
              index: index,
              count: 3,
              doublePage: false,
              layoutToken: 'portrait',
              pageBuilder: (leaf, _) => ColoredBox(
                color: Colors.amber.shade100,
                child: Text('Feuille $leaf'),
              ),
              onChanged: (next) => index = next,
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene(false));
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(CodexPageTurn)),
      );
      await finger.moveBy(const Offset(-20, 0));
      await tester.pump();
      await finger.moveBy(const Offset(-25, 0));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await finger.up();
      await tester.pumpAndSettle();
      expect(index, 0);
      await tester.pumpWidget(scene(true));
      key.currentState!.turnTo(1);
      await tester.pumpAndSettle();
      expect(index, 1);
      expect(find.byKey(const ValueKey('codex-curled-sheet')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
