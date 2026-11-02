import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/services/immersion_preferences.dart';
import 'package:mordeviel/village/house_contour_light.dart';
import 'package:mordeviel/village/intense_house_contours.g.dart';

void main() {
  test('Les trois silhouettes suivent des contours fermés utilisables', () {
    for (final state in ['day', 'night', 'eliminated']) {
      final points = intenseHouseContours[state]!;
      expect(points.length, greaterThan(20));
      expect(
        points.every((p) => p.dx >= 0 && p.dx <= 1 && p.dy >= 0 && p.dy <= 1),
        isTrue,
      );
    }
  });

  testWidgets(
    'La lumière s’arrête en pause, en arrière-plan et en mode allégé',
    (tester) async {
      ImmersionPreferences.instance.lightEffects = false;
      addTearDown(() => ImmersionPreferences.instance.lightEffects = false);
      Widget scene({bool paused = false, bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: SizedBox(
              width: 238,
              height: 238,
              child: HouseContourLight(
                state: 'night',
                paused: paused,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(scene(paused: true));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(scene());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(scene(reduced: true));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
