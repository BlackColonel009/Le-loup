import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'package:local_host/src/sentence_draw.dart';
import 'package:mordeviel/joining/host_identity.dart';
import 'package:mordeviel/joining/room_entrance.dart';
import 'package:mordeviel/village/ceremonies.dart';
import 'background_game_test.dart' show waitUntil;

void main() {
  for (final reduced in [false, true]) {
    testWidgets('L’entrée se termine seule, mouvements réduits : $reduced', (
      tester,
    ) async {
      var ended = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: RoomEntranceScreen(
              theme: 'classic',
              onComplete: () => ended++,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(Duration(milliseconds: reduced ? 650 : 2900));
      expect(ended, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(ended, 1);
    });
  }
  test('Les sentences parcourent les huit choix avant de se répéter', () {
    final draw = SentenceDraw(Random(19));
    int? previous;
    for (var cycle = 0; cycle < 20; cycle++) {
      final used = <int>{};
      for (var i = 0; i < 8; i++) {
        final next = draw.next(8);
        expect(next, isNot(previous));
        expect(used.add(next), isTrue);
        previous = next;
      }
    }
  });
  test(
    'Le bilan nocturne et la sentence appartiennent à deux révélations distinctes',
    () {
      final game = NightGame({
        'w': 'werewolf',
        'a': 'villager',
        'b': 'villager',
        'c': 'villager',
        'd': 'villager',
        'e': 'villager',
      });
      game.startNight();
      game.callNight('wolves');
      game.act('w', {
        'action': 'wolves.choose',
        'phase_revision': game.revision,
        'target': 'a',
      });
      game.advance();
      game.finishNight();
      final night = (game.publicState['death_events'] as List).single as Map;
      expect(night['batch'], 'night-1');
      game.advance();
      game.startVote();
      expect(game.publicState['death_batch'], 'vote-1');
      expect(game.publicState['deaths'], isEmpty);
      for (final id in game.alive.toList()) {
        game.act(id, {
          'action': 'vote.cast',
          'phase_revision': game.revision,
          'target': 'b',
        });
      }
      game.advance();
      final events = game.publicState['death_events'] as List;
      expect(events.length, 2);
      expect(events.last['batch'], 'vote-1');
      expect(events.last['cause'], 'vote');
      expect(game.publicState['deaths'], ['b']);
    },
  );
  test(
    'La Sorcière révèle le sauvetage au lever du jour au seul joueur concerné',
    () {
      final game = NightGame({
        'w': 'werewolf',
        's': 'witch',
        'a': 'villager',
        'b': 'villager',
        'c': 'villager',
      }, revealRescuer: true);
      game.startNight();
      game.callNight('wolves');
      game.act('w', {
        'action': 'wolves.choose',
        'phase_revision': game.revision,
        'target': 'a',
      });
      game.advance();
      game.callNight('witch');
      game.act('s', {
        'action': 'witch.potions',
        'phase_revision': game.revision,
        'save': true,
        'kill': null,
      });
      expect(game.privateState('a')['rescues'], isEmpty);
      game.advance();
      game.finishNight();
      expect(
        (game.privateState('a')['rescues'] as List).single['rescuer'],
        's',
      );
      expect(game.privateState('b')['rescues'], isEmpty);
      expect(game.alive.contains('a'), isTrue);
    },
  );
  test('Le nom du compte reste privé au MDJ sur le transport local', () async {
    final host = LocalHost();
    final client = LobbyClient();
    final public = <Map<String, dynamic>>[];
    final subscription = client.events.listen((e) {
      if (e['type'] == 'room.snapshot') public.add(e);
    });
    addTearDown(() async {
      await subscription.cancel();
      await client.dispose();
      await host.dispose();
    });
    await host.start(port: 0, bindAddress: '127.0.0.1');
    await client.connect(
      '127.0.0.1:${host.port}',
      host.code,
      'Loup',
      communityNickname: 'Kossi',
    );
    await waitUntil(() => client.id != null && public.isNotEmpty);
    expect((host.snapshot['account_names'] as Map)[client.id], 'Kossi');
    expect(public.last.containsKey('account_names'), isFalse);
    expect((public.last['players'] as List).single['nickname'], 'Loup');
    final displayed = hostDisplayRoom(host.snapshot);
    expect((displayed['players'] as List).single['nickname'], 'Loup (Kossi)');
    expect((host.snapshot['players'] as List).single['nickname'], 'Loup');
  });
  test(
    'La roue est rejetée pendant le compte à rebours et le salon reste vivant',
    () async {
      final host = LocalHost(
        transitionDelay: const Duration(milliseconds: 100),
      );
      final clients = List.generate(4, (_) => LobbyClient());
      addTearDown(() async {
        for (final c in clients) {
          await c.dispose();
        }
        await host.dispose();
      });
      await host.start(port: 0, bindAddress: '127.0.0.1');
      for (var i = 0; i < clients.length; i++) {
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
      host.startNight();
      host.finishNight();
      host.advanceNight();
      host.startVote();
      if (host.snapshot['phase'] == 'mayor_election') {
        host.advanceNight();
        host.startVote();
      }
      final victim =
          (host.snapshot['assignments'] as Map).entries
                  .firstWhere((e) => e.value == 'villager')
                  .key
              as String;
      final revision = (host.snapshot['game'] as Map)['phase_revision'] as int;
      for (final c in clients) {
        c.gameAction('vote.cast', revision, target: victim);
      }
      await waitUntil(
        () => (host.snapshot['game'] as Map)['votes_received'] == 4,
      );
      host.advanceNight();
      expect(host.snapshot['phase'], 'vote_result');
      host.schedulePhase('night');
      expect(() => host.spinSentence(), throwsStateError);
      await waitUntil(() => host.snapshot['phase'] == 'sleep');
      expect((host.snapshot['game'] as Map)['night'], 2);
      expect(host.snapshot['transition'], isNull);
    },
  );
  testWidgets('Le bouton de roue est désactivé pendant une transition', (
    tester,
  ) async {
    var spins = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SentenceWheel(
              game: const {
                'phase': 'vote_result',
                'vote_result': {'eliminated': 'a'},
              },
              isHost: true,
              transitionPending: true,
              onSpin: () => spins++,
              name: (_) => 'Alice',
            ),
          ),
        ),
      ),
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Changement de phase en cours…'),
    );
    expect(button.onPressed, isNull);
    expect(spins, 0);
  });
  for (final entry in {
    'classic': 'Classique',
    'intense': 'Intense',
    'horror': 'Horreur',
  }.entries) {
    testWidgets(
      'Entrée ${entry.value} lisible, finie et passable en petit paysage',
      (tester) async {
        tester.view.physicalSize = const Size(640, 360);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var ended = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: RoomEntranceScreen(
              theme: entry.key,
              onComplete: () => ended++,
            ),
          ),
        );
        await tester.pump();
        expect(find.text(entry.value), findsOneWidget);
        await tester.tap(find.text('Passer'));
        expect(ended, 1);
        await tester.pump(const Duration(seconds: 4));
        expect(ended, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
