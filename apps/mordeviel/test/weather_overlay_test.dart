import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'package:mordeviel/village/weather_overlay.dart';

void main() {
  testWidgets('La neige Intense reste visible sans bloquer les maisons', (tester) async {
    var taps = 0;
    expect(VillageWeather.fromMap({'kind':'snow'}).snowing, isTrue);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Stack(fit: StackFit.expand,
      children: [Center(child: TextButton(onPressed: () => taps++, child: const Text('Maison'))),
        const Positioned.fill(child: WeatherOverlay(weather: VillageWeather(kind: 'snow')))]))));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Maison'));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Neige sur le village'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('La pluie ne bloque pas les interactions avec le village', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: ElevatedButton(
                  onPressed: () => taps++,
                  child: const Text('Maison'),
                ),
              ),
              const Positioned.fill(
                child: WeatherOverlay(
                  weather: VillageWeather(kind: 'storm', seed: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Maison'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Orage nocturne'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'La météo devient une lueur après la pluie puis disparaît au ciel clair',
    (tester) async {
      var weather = const VillageWeather(kind: 'rain', seed: 12);
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return WeatherOverlay(weather: weather);
              },
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Pluie nocturne'), findsOneWidget);
      update(() => weather = const VillageWeather(rainbow: true, night: 1));
      await tester.pump();
      expect(find.bySemanticsLabel('Lueur d’arc-en-ciel'), findsOneWidget);
      expect(find.bySemanticsLabel('Pluie nocturne'), findsNothing);
      update(() => weather = const VillageWeather());
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel('Lueur d’arc-en-ciel'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
  testWidgets(
    'Animations réduites : orage statique et absence de ticker continu',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SizedBox.expand(
              child: WeatherOverlay(
                weather: VillageWeather(
                  kind: 'storm',
                  seed: 0,
                  elapsedMs: 4400,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Orage nocturne'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
  test(
    'Les horaires d’orage sont identiques à partir de la graine publique',
    () {
      const a = VillageWeather(kind: 'storm', seed: 84);
      final b = VillageWeather.fromMap({'kind': 'storm', 'seed': 84});
      for (var slot = 0; slot < 10; slot++) {
        expect(a.flashAt(slot), b.flashAt(slot));
        expect(a.thunderAt(a.flashAt(slot) + 700), slot);
        expect(a.lightningAt(a.flashAt(slot) + 400), lessThanOrEqualTo(.17));
      }
    },
  );
}
