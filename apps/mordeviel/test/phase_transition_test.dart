import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'package:mordeviel/village/phase_transition_banner.dart';
import 'background_game_test.dart' show waitUntil;

void main() {
  testWidgets(
    'Le compte à rebours reste au-dessus d’une fenêtre ouverte et se retire proprement',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      const AlertDialog(title: Text('Codex ouvert')),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      final notice = PhaseTransitionNotice();
      notice.update(context, {
        'target': 'day',
        'remaining_ms': 5000,
      }, 'intense');
      await tester.pump();
      expect(find.text('Jour dans : 5 secondes'), findsOneWidget);
      expect(find.text('Codex ouvert'), findsOneWidget);
      notice.update(context, null, 'intense');
      await tester.pump();
      expect(find.textContaining('Jour dans'), findsNothing);
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Le moteur attend, annonce la transition à tous, puis change réellement de phase',
    () async {
      expect(LocalHost().transitionDelay, const Duration(seconds: 5));
      final host = LocalHost(
        transitionDelay: const Duration(milliseconds: 150),
      );
      final clients = List.generate(4, (_) => LobbyClient());
      final sawTransition = <int>{};
      final subscriptions = <StreamSubscription>[];
      addTearDown(() async {
        for (final s in subscriptions) {
          await s.cancel();
        }
        for (final c in clients) {
          await c.dispose();
        }
        await host.dispose();
      });
      await host.start(nickname: 'MDJ', port: 0, bindAddress: '127.0.0.1');
      for (var i = 0; i < 4; i++) {
        subscriptions.add(
          clients[i].events.listen((e) {
            if (e['transition'] is Map) sawTransition.add(i);
          }),
        );
        await clients[i].connect(
          '127.0.0.1:${host.port}',
          host.code,
          'Joueur $i',
        );
        await waitUntil(() => clients[i].id != null);
        clients[i].setReady(true);
      }
      await waitUntil(
        () =>
            (host.snapshot['players'] as List).every((p) => p['ready'] == true),
      );
      host.startGame();
      host.schedulePhase('night');
      expect(host.snapshot['phase'], 'role_reveal');
      expect((host.snapshot['transition'] as Map)['target'], 'night');
      expect(() => host.schedulePhase('day'), throwsStateError);
      await waitUntil(() => sawTransition.length == 4);
      await waitUntil(() => host.snapshot['phase'] == 'sleep');
      expect(host.snapshot['transition'], isNull);
      host.schedulePhase('day');
      expect(host.snapshot['phase'], 'sleep');
      await waitUntil(() => host.snapshot['phase'] == 'dawn');
      expect(host.snapshot['transition'], isNull);
    },
  );

  testWidgets(
    'Le bandeau compte cinq secondes sans changer sa lisibilité selon le thème',
    (tester) async {
      for (final theme in ['classic', 'intense', 'horror']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PhaseTransitionBanner(
                key: ValueKey(theme),
                theme: theme,
                transition: const {'target': 'night', 'remaining_ms': 5000},
              ),
            ),
          ),
        );
        expect(find.text('Nuit dans : 5 secondes'), findsOneWidget);
        if (theme == 'classic') {
          // The banner uses a monotonic clock, independent of Flutter frames.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1050)),
          );
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('Nuit dans : 4 secondes'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
