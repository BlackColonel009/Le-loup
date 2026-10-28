import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/audio/classic_audio.dart';
import 'package:mordeviel/audio/voice_profiles.dart';
import 'package:mordeviel/village/ending_data.dart';
import 'package:mordeviel/cards/classic_role.dart';
import 'classic_audio_test.dart' show FakeAudio, recordedTestProfiles, state;

Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Tous les rôles et la Villageoise disposent de dernières paroles', () {
    expect(deathSpeeches.keys.toSet(), classicRoles.map((r) => r.id).toSet());
    expect(deathSpeechFor('villager', feminine: true), villagerFemaleSpeech);
    expect(deathSpeechFor(null), isNull);
    for (final speech in deathSpeeches.values) {
      expect(speech.text, isNotEmpty);
    }
  });
  test(
    'Passer une carte coupe sa voix puis démarre celle de la suivante',
    () async {
      final backend = FakeAudio();
      final audio = ClassicAudio(
        backend: backend,
        profiles: recordedTestProfiles,
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      audio.room(state('ended', 10), isHost: true);
      await audio.settled;
      audio.deathSpeech('seer');
      await flush();
      expect(backend.calls.last, 'neural/classic_female/death_seer.wav');
      audio.stopDeathSpeech();
      audio.deathSpeech('guardian');
      await flush();
      expect(backend.calls.last, 'neural/intense_male/death_guardian.wav');
      backend.completed.add(null);
      await audio.settled;
      expect(audio.error, isNull);
    },
  );
  test(
    'Dernières paroles puis jingle puis victoire, sans chevauchement',
    () async {
      final backend = FakeAudio();
      final audio = ClassicAudio(
        backend: backend,
        profiles: recordedTestProfiles,
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      audio.room(state('ended', 10), isHost: true);
      await audio.settled;
      backend.calls.clear();
      audio.deathSpeech('hunter');
      audio.ending('village');
      await flush();
      expect(backend.calls.last, 'neural/intense_male/death_hunter.wav');
      backend.completed.add(null);
      await flush();
      expect(backend.calls.last, 'ending_bright.wav');
      expect(backend.calls, isNot(contains('neural/duke/ended_village.wav')));
      backend.completed.add(null);
      await flush();
      expect(backend.calls.last, 'neural/duke/ended_village.wav');
      backend.completed.add(null);
      await audio.settled;
      expect(audio.error, isNull);
    },
  );

  test(
    'Voix coupées : le jingle sombre reste audible pour les Loups',
    () async {
      final backend = FakeAudio();
      final audio = ClassicAudio(
        backend: backend,
        profiles: recordedTestProfiles,
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      audio.levels(narration: false);
      audio.room(state('ended', 10), isHost: true);
      await audio.settled;
      backend.calls.clear();
      audio.deathSpeech('seer');
      audio.ending('wolves');
      await flush();
      expect(backend.calls.where((s) => s.endsWith('.wav')), [
        'ending_dark.wav',
      ]);
      backend.completed.add(null);
      await audio.settled;
      expect(backend.calls.where((s) => s.endsWith('.wav')), [
        'ending_dark.wav',
      ]);
    },
  );

  test('Rôle secret et joueur local : aucune réplique révélatrice', () async {
    final backend = FakeAudio();
    final audio = ClassicAudio(
      backend: backend,
      profiles: recordedTestProfiles,
      fadeDuration: Duration.zero,
    );
    addTearDown(audio.dispose);
    audio.room(state('ended', 10), isHost: true);
    await audio.settled;
    backend.calls.clear();
    audio.deathSpeech(null);
    await audio.settled;
    expect(backend.calls, isEmpty);
    audio.room(state('ended', 10), isHost: false);
    await audio.settled;
    backend.calls.clear();
    audio.deathSpeech('elder', cursed: true);
    audio.ending('wolves');
    await audio.settled;
    expect(backend.calls, isEmpty);
  });

  test('Quitter la partie annule une annonce en cours et sa suite', () async {
    final backend = FakeAudio();
    final audio = ClassicAudio(
      backend: backend,
      profiles: recordedTestProfiles,
      fadeDuration: Duration.zero,
    );
    addTearDown(audio.dispose);
    audio.room(state('ended', 10), isHost: true);
    await audio.settled;
    audio.deathSpeech('elder', cursed: true);
    audio.ending('village');
    await flush();
    expect(backend.calls.last, 'neural/old_wizard/elder_curse.wav');
    audio.room(null, isHost: false);
    await audio.settled;
    expect(backend.calls, isNot(contains('ending_bright.wav')));
    expect(audio.error, isNull);
  });

  test('Silence général annule la suite de la cérémonie', () async {
    final backend = FakeAudio();
    final audio = ClassicAudio(
      backend: backend,
      profiles: recordedTestProfiles,
      fadeDuration: Duration.zero,
    );
    addTearDown(audio.dispose);
    audio.room(state('ended', 10), isHost: true);
    await audio.settled;
    audio.ending('wolves');
    await flush();
    expect(backend.calls.last, 'ending_dark.wav');
    audio.levels(mute: true);
    await audio.settled;
    expect(backend.calls, isNot(contains('neural/werewolf/ended_wolves.wav')));
    expect(audio.error, isNull);
  });

  test('Toutes les nouvelles annonces sont déclarées et livrées', () {
    for (final ending in gameEndings.values) {
      final profile = voiceProfileById(ending.profile);
      expect(profile.supports(ending.cue), isTrue);
      expect(
        File(
          'assets/audio/classic/${profile.assetFor(ending.cue)}',
        ).existsSync(),
        isTrue,
      );
    }
    for (final speech in [
      ...deathSpeeches.values,
      elderCurseSpeech,
      villagerFemaleSpeech,
    ]) {
      final profile = voiceProfileById(speech.profile);
      expect(profile.supports(speech.cue), isTrue);
      expect(
        File(
          'assets/audio/classic/${profile.assetFor(speech.cue)}',
        ).existsSync(),
        isTrue,
      );
    }
    for (final asset in ['ending_bright.wav', 'ending_dark.wav']) {
      expect(
        File('assets/audio/classic/$asset').lengthSync(),
        greaterThan(100000),
      );
    }
  });
}
