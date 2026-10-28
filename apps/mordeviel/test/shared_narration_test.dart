import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:mordeviel/audio/voice_profiles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'package:mordeviel/audio/classic_audio.dart';
import 'package:mordeviel/village/village_map.dart';
import 'classic_audio_test.dart' show FakeAudio, recordedTestProfiles;
import 'ending_audio_test.dart' show flush;
import 'village_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Les dix voix livrent chaque texte exact des appels et rendormissements',
    () {
      for (final profile in voiceProfiles) {
        final directory = 'assets/audio/classic/${profile.prefix}';
        final manifest =
            jsonDecode(File('${directory}manifest.json').readAsStringSync())
                as Map;
        for (final line in mdjNarrationLines.entries) {
          final cue = 'mdj_${line.key}';
          expect(
            profile.supports('$cue.wav'),
            isTrue,
            reason: '${profile.id}/$cue',
          );
          expect(File('$directory$cue.wav').existsSync(), isTrue);
          expect(manifest['cues'][cue]['text'], line.value);
        }
      }
    },
    tags: 'narration_assets',
  );
  test(
    'Le salon partage le profil et le mode automatique, sans toucher aux rôles',
    () async {
      final host = LocalHost();
      addTearDown(host.dispose);
      await host.start(port: 0);
      host.setNarration(profile: 'duke', automatic: false);
      expect(host.snapshot['narration_profile'], 'duke');
      expect(host.snapshot['automatic_narration'], isFalse);
      expect(
        () => host.setNarration(profile: 'windows', automatic: true),
        throwsArgumentError,
      );
    },
  );
  test(
    'Appel et rendormissement sont des annonces publiques sans identités',
    () {
      final game = NightGame({
        's': 'seer',
        'w': 'werewolf',
        'a': 'villager',
        'b': 'villager',
      });
      game.startNight();
      game.callNight('seer');
      game.advance();
      expect(game.phase, 'sleep');
      expect(game.announcement, mdjNarrationLines['close_seer']);
      final events = game.publicState['narration_events'] as List;
      expect(events.last['cue'], 'mdj_close_seer.wav');
      expect(events.map((e) => e['revision']).toSet().length, events.length);
      expect(
        events.any((e) => e.containsKey('actor') || e.containsKey('target')),
        isFalse,
      );
    },
  );
  test(
    'La voix du MDJ remplace le choix personnel et les appels restent ordonnés',
    () async {
      final backend = FakeAudio();
      final audio = ClassicAudio(
        backend: backend,
        profiles: recordedTestProfiles,
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      audio.selectVoice('ghost');
      final lobby = <String, dynamic>{
        'code': 'ABC123',
        'narration_profile': 'duke',
        'automatic_narration': true,
      };
      audio.room(lobby, isHost: true);
      await audio.settled;
      backend.calls.clear();
      final playing = {
        ...lobby,
        'game': {
          'phase': 'sleep',
          'narration_events': [
            {'revision': 1, 'cue': 'mdj_sleep.wav'},
            {'revision': 2, 'cue': 'mdj_seer.wav'},
            {'revision': 3, 'cue': 'mdj_close_seer.wav'},
          ],
        },
      };
      audio.room(playing, isHost: true);
      audio.room(playing, isHost: true);
      expect(audio.voiceProfile.id, 'duke');
      await flush();
      expect(backend.calls.last, 'neural/duke/mdj_sleep.wav');
      backend.completed.add(null);
      await flush();
      expect(backend.calls.last, 'neural/duke/mdj_seer.wav');
      backend.completed.add(null);
      await flush();
      expect(backend.calls.last, 'neural/duke/mdj_close_seer.wav');
      backend.completed.add(null);
      await audio.settled;
      expect(backend.calls.where((c) => c.endsWith('.wav')).length, 3);
      audio.room({
        ...playing,
        'automatic_narration': false,
        'game': {
          'phase': 'wolves',
          'narration_events': [
            {'revision': 4, 'cue': 'mdj_wolves.wav'},
          ],
        },
      }, isHost: true);
      await audio.settled;
      expect(backend.calls, isNot(contains('neural/duke/mdj_wolves.wav')));
      audio.room(null, isHost: false);
      await audio.settled;
      expect(audio.voiceProfile.id, 'ghost');
    },
  );
  test(
    'Une reconnexion reprend le dernier appel sans rejouer les anciens',
    () async {
      final backend = FakeAudio();
      final audio = ClassicAudio(
        backend: backend,
        profiles: recordedTestProfiles,
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      final lobby = <String, dynamic>{
        'code': 'ABC123',
        'narration_profile': 'duke',
      };
      audio.room(lobby, isHost: true);
      await audio.settled;
      final first = {
        ...lobby,
        'game': {
          'phase': 'seer',
          'narration_events': [
            {'revision': 1, 'cue': 'mdj_sleep.wav'},
            {'revision': 2, 'cue': 'mdj_seer.wav'},
          ],
        },
      };
      audio.room(first, isHost: true);
      await flush();
      audio.room(first, isHost: false);
      await audio.settled;
      backend.calls.clear();
      audio.room({
        ...lobby,
        'game': {
          'phase': 'wolves',
          'narration_events': [
            ...first['game']!['narration_events'] as List,
            {'revision': 3, 'cue': 'mdj_close_seer.wav'},
            {'revision': 4, 'cue': 'mdj_wolves.wav'},
          ],
        },
      }, isHost: true);
      await flush();
      expect(backend.calls.where((s) => s.endsWith('.wav')).toList(), [
        'neural/duke/mdj_wolves.wav',
      ]);
      backend.completed.add(null);
      await audio.settled;
    },
  );
  test('Rejoindre une partie terminée ne relit pas un ancien appel', () async {
    final backend = FakeAudio();
    final audio = ClassicAudio(
      backend: backend,
      profiles: recordedTestProfiles,
      fadeDuration: Duration.zero,
    );
    addTearDown(audio.dispose);
    audio.room({
      'code': 'END123',
      'narration_profile': 'duke',
      'game': {
        'phase': 'ended',
        'narration_events': [
          {'revision': 9, 'cue': 'mdj_voting.wav'},
        ],
      },
    }, isHost: true);
    await audio.settled;
    expect(backend.calls.where((s) => s.endsWith('.wav')), isEmpty);
    expect(audio.canReplay, isFalse);
  });
  for (final intense in [false, true]) {
    testWidgets('Ombre de préparation puis élimination, thème $intense', (
      tester,
    ) async {
      final room = fixtures.room();
      room.remove('game');
      room['phase'] = 'lobby';
      room['visual_pack'] = intense ? 'intense' : 'classic';
      (room['players'] as List).first['ready'] = true;
      Widget view(Map<String, dynamic> state) => MaterialApp(
        home: Scaffold(
          body: VillageMap(room: state, onHouse: (_) {}, onChat: () {}),
        ),
      );
      await tester.pumpWidget(view(room));
      expect(find.byKey(const ValueKey('house-glow-p0-ready')), findsOneWidget);
      expect(find.byKey(const ValueKey('house-glow-p1-ready')), findsNothing);
      await tester.pumpWidget(
        view({
          ...room,
          'phase': 'day',
          'game': {
            'alive_ids': [for (var i = 0; i < 19; i++) 'p$i'],
          },
        }),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('house-glow-p0-ready')), findsNothing);
      expect(
        find.byKey(const ValueKey('house-glow-p19-eliminated')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
