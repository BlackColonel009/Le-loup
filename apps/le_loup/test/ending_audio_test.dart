import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/audio/classic_audio.dart';
import 'package:le_loup/audio/voice_profiles.dart';
import 'package:le_loup/village/ending_data.dart';
import 'classic_audio_test.dart' show FakeAudio, recordedTestProfiles, state;

Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
      expect(backend.calls, ['neural/intense_male/death_hunter.wav']);
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
      expect(backend.calls, ['ending_dark.wav']);
      backend.completed.add(null);
      await audio.settled;
      expect(backend.calls, ['ending_dark.wav']);
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
      (profile: 'old_wizard', cue: 'elder_curse.wav'),
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
