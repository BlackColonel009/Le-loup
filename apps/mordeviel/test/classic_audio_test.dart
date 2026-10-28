import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/audio/classic_audio.dart';
import 'package:mordeviel/audio/voice_profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAudio implements AudioBackend {
  final completed = StreamController<void>.broadcast(sync: true);
  final calls = <String>[];
  double bed = 0;
  bool fail = false;
  final weatherCalls = <String?>[];
  double rainVolume = 0;
  int thunders = 0;
  @override
  Future<void> weather(String? asset, double volume) async {
    weatherCalls.add(asset);
    rainVolume = asset == null ? 0 : volume;
  }

  @override
  Future<void> thunder(double volume) async {
    thunders++;
  }

  @override
  Stream<void> get cueFinished => completed.stream;
  @override
  Future<void> music(double volume) async {
    calls.add('music');
    bed = volume;
  }

  @override
  Future<void> cue(String asset, double volume) async {
    if (fail) throw StateError('No audio device');
    calls.add(asset);
  }

  @override
  Future<void> musicVolume(double volume) async {
    bed = volume;
  }

  @override
  Future<void> cueVolume(double volume) async {
    calls.add('cue-volume:$volume');
  }

  @override
  Future<void> stopCue() async {
    calls.add('stop-cue');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    bed = 0;
    rainVolume = 0;
  }

  @override
  Future<void> dispose() async {
    await completed.close();
  }
}

// Métadonnées fictives de voix enregistrées : FakeAudio ne lit aucun fichier.
final recordedTestProfiles = voiceProfiles
    .map(
      (p) => VoiceProfile(
        p.id,
        p.label,
        p.edition,
        'Interprète fictif pour les tests du lecteur.',
        p.prefix,
        isApproved: true,
      ),
    )
    .toList(growable: false);

Map<String, dynamic> state(String phase, int revision) => {
  'code': '123456',
  'phase': phase,
  'game': {
    'phase': phase,
    'phase_revision': revision,
    'night': 1,
    'winner': 'village',
  },
};

void main() {
  test(
    'La présentation attend la fin du hurlement et passe si le son est coupé',
    () async {
      final backend = FakeAudio();
      final audio = ClassicAudio(backend: backend, fadeDuration: Duration.zero);
      audio.welcome();
      var done = false;
      final waiting = audio.welcomeHowlFinished.then((_) => done = true);
      await audio.settled;
      expect(done, isFalse);
      backend.completed.add(null);
      await waiting;
      expect(done, isTrue);
      audio.dispose();
      final silent = ClassicAudio(
        backend: FakeAudio(),
        fadeDuration: Duration.zero,
      )..muted = true;
      silent.welcome();
      await silent.welcomeHowlFinished;
      silent.dispose();
    },
  );
  test(
    'Réactiver les voix permet de tester un extrait, même depuis le salon silencieux',
    () async {
      final backend = FakeAudio();
      final audio = ClassicAudio(
        backend: backend,
        profiles: recordedTestProfiles,
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      audio.levels(narration: false);
      await audio.settled;
      expect(audio.canPreviewVoice, isFalse);
      audio.levels(narration: true);
      await audio.settled;
      expect(audio.canPreviewVoice, isTrue);
      audio.previewVoice();
      await audio.settled;
      expect(backend.calls.last, 'neural/classic_male/preview.wav');
      expect(backend.bed, 0);
    },
  );
  test(
    'La potion confirmée déclenche une seule réplique de vieille sorcière chez le MDJ',
    () async {
      final backend = FakeAudio();
      final audio = ClassicAudio(
        backend: backend,
        profiles: recordedTestProfiles,
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      final room = state('witch', 12);
      room['game_host'] = {'potion_used': false};
      audio.room(room, isHost: true);
      await audio.settled;
      final before = backend.calls.length;
      audio.room(room, isHost: true);
      await audio.settled;
      expect(backend.calls.length, before);
      room['game_host'] = {'potion_used': true};
      audio.room(room, isHost: true);
      audio.room(room, isHost: true);
      await audio.settled;
      expect(
        backend.calls
            .where((a) => a == 'neural/old_witch/witch_potion.wav')
            .length,
        1,
      );
      final playerBackend = FakeAudio();
      final player = ClassicAudio(
        backend: playerBackend,
        profiles: recordedTestProfiles,
      );
      addTearDown(player.dispose);
      player.room(room, isHost: false);
      await player.settled;
      expect(
        playerBackend.calls.where((a) => a.endsWith('witch_potion.wav')),
        isEmpty,
      );
    },
  );
  test(
    'Le retour au choix des appels ne répète pas l’endormissement',
    () async {
      final backend = FakeAudio();
      final audio = ClassicAudio(
        backend: backend,
        profiles: recordedTestProfiles,
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      audio.room(state('wolves', 1), isHost: true);
      await audio.settled;
      final menu = state('sleep', 2);
      (menu['game'] as Map)['night_menu'] = true;
      audio.room(menu, isHost: true);
      await audio.settled;
      expect(audio.canReplay, isFalse);
      expect(backend.calls.where((a) => a.endsWith('sleep.wav')), isEmpty);
      audio.room(state('seer', 3), isHost: true);
      await audio.settled;
      expect(backend.calls.last, 'neural/classic_male/seer.wav');
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  late ClassicAudio audio;
  late FakeAudio backend;
  setUp(() {
    backend = FakeAudio();
    audio = ClassicAudio(
      backend: backend,
      profiles: recordedTestProfiles,
      fadeDuration: Duration.zero,
    );
  });
  tearDown(() async {
    audio.dispose();
    await audio.settled;
  });
  test(
    'Aucune ancienne voix non validée active, même avec un ancien choix mémorisé',
    () async {
      final realBackend = FakeAudio();
      final humanOnly = ClassicAudio(
        backend: realBackend,
        profiles: voiceProfiles.where((p) => !p.isApproved).toList(),
        fadeDuration: Duration.zero,
      );
      SharedPreferences.setMockInitialValues({'audio.voiceProfile': 'ghost'});
      humanOnly.restoreSettings(await SharedPreferences.getInstance());
      humanOnly.room(state('wolves', 3), isHost: true);
      await humanOnly.settled;
      humanOnly.previewVoice();
      humanOnly.replay();
      await humanOnly.settled;
      expect(humanOnly.availableVoices, isEmpty);
      expect(humanOnly.canPreviewVoice, isFalse);
      expect(humanOnly.canReplay, isFalse);
      expect(realBackend.calls.where((s) => s.endsWith('.wav')), isEmpty);
      humanOnly.dispose();
    },
  );
  test(
    'Le choix de voix ne relance pas une phase et sert aux prochains appels',
    () async {
      audio.room(state('wolves', 3), isHost: true);
      await audio.settled;
      final before = List<String>.of(backend.calls);
      audio.selectVoice('classic_female');
      audio.room(state('wolves', 3), isHost: true);
      await audio.settled;
      expect(backend.calls, before);
      audio.replay();
      await audio.settled;
      expect(backend.calls.last, 'neural/classic_female/wolves.wav');
      audio.selectVoice('duke');
      audio.room(state('witch', 4), isHost: true);
      await audio.settled;
      expect(backend.calls.last, 'neural/duke/witch.wav');
    },
  );
  test(
    'Un extrait manuel reste disponible hors narration automatique',
    () async {
      audio.selectVoice('ghost');
      audio.room(state('seer', 2), isHost: true);
      await audio.settled;
      audio.previewVoice();
      await audio.settled;
      expect(backend.calls.last, 'neural/ghost/preview.wav');
      audio.replay();
      await audio.settled;
      expect(backend.calls.last, 'neural/ghost/seer.wav');
      audio.silence();
      await audio.settled;
      audio.previewVoice();
      await audio.settled;
      expect(audio.canPreviewVoice, true);
      expect(backend.calls.last, 'neural/ghost/preview.wav');
      expect(backend.bed, 0);
    },
  );
  test('La voix et les volumes sont mémorisés sur l’appareil', () async {
    SharedPreferences.setMockInitialValues({
      'audio.voiceProfile': 'classic_female',
      'audio.voice': .7,
    });
    final prefs = await SharedPreferences.getInstance();
    audio.restoreSettings(prefs);
    expect(audio.voiceProfile.id, 'classic_female');
    expect(audio.voiceLevel, .7);
    audio.selectVoice('old_witch');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(prefs.getString('audio.voiceProfile'), 'old_witch');
    final other = ClassicAudio(
      backend: FakeAudio(),
      profiles: recordedTestProfiles,
      fadeDuration: Duration.zero,
    );
    other.restoreSettings(prefs);
    expect(other.voiceProfile.id, 'old_witch');
    expect(other.voiceLevel, .7);
    other.dispose();
  });
  test('Ancien profil inconnu : retour à la voix classique masculine', () {
    expect(voiceProfileById('obsolete').id, 'classic_male');
    expect(
      voiceProfileById(null).assetFor('wolves.wav'),
      'neural/classic_male/wolves.wav',
    );
  });
  test('Les dix profils installés utilisent les nouveaux rendus neuronaux', () {
    expect(voiceProfiles.map((p) => p.id).toSet().length, 10);
    expect(voiceProfiles.every((p) => p.isApproved), isTrue);
    expect(voiceProfiles.every((p) => p.prefix.startsWith('neural/')), isTrue);
    expect(voiceProfiles.where((p) => p.edition == 'Classique').length, 2);
    expect(voiceProfiles.where((p) => p.edition == 'Intense').length, 3);
    expect(voiceProfiles.where((p) => p.edition == 'Horreur').length, 5);
    for (final profile in voiceProfiles.where((p) => p.isApproved)) {
      for (final cue in [...ClassicAudio.voiceAssets, 'preview.wav']) {
        if (!profile.supports(cue)) continue;
        expect(
          File('assets/audio/classic/${profile.assetFor(cue)}').lengthSync(),
          greaterThan(1000),
        );
      }
    }
  });
  test(
    'Les annonces manquantes ne lisent jamais les anciens fichiers Windows',
    () async {
      final backend = FakeAudio();
      final production = ClassicAudio(
        backend: backend,
        profiles: const [
          VoiceProfile(
            'werewolf',
            'Loup-garou',
            'Horreur',
            'Pack partiel de test',
            'neural/werewolf/',
            isApproved: true,
            availableCues: {'preview.wav', 'wolves.wav'},
          ),
        ],
        fadeDuration: Duration.zero,
      );
      addTearDown(production.dispose);
      production.selectVoice('werewolf');
      production.room(state('seer', 1), isHost: true);
      await production.settled;
      expect(production.canReplay, isFalse);
      production.replay();
      await production.settled;
      expect(backend.calls.where((s) => s.endsWith('.wav')), isEmpty);
      production.room(state('wolves', 2), isHost: true);
      await production.settled;
      expect(backend.calls, contains('neural/werewolf/wolves.wav'));
      expect(production.canReplay, isTrue);
      production.selectVoice('classic_male');
      expect(production.voiceProfile.isApproved, isTrue);
      expect(production.voiceProfile.prefix, startsWith('neural/'));
    },
  );
  test(
    'Orage local : pluie dédiée, grondement unique et priorité aux voix',
    () async {
      final room = state('wolves', 3);
      (room['game'] as Map)['weather'] = {
        'kind': 'storm',
        'seed': 0,
        'night': 1,
        'elapsed_ms': 5000,
      };
      audio.room(room, isHost: true);
      await audio.settled;
      expect(backend.weatherCalls, contains('rain_loop.wav'));
      final ducked = backend.rainVolume;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await audio.settled;
      expect(backend.thunders, 0); // Ne couvre pas l'appel des loups.
      backend.completed.add(null);
      await audio.settled;
      expect(backend.rainVolume, greaterThan(ducked));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await audio.settled;
      expect(backend.thunders, 1);
      audio.room(room, isHost: true);
      await audio.settled;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await audio.settled;
      expect(backend.thunders, 1);
      expect(backend.calls.where((s) => s.endsWith('.wav')).toList(), [
        'neural/classic_male/wolves.wav',
      ]);
      audio.levels(mute: true);
      await audio.settled;
      expect(backend.rainVolume, 0);
      audio.levels(mute: false);
      await audio.settled;
      expect(backend.rainVolume, greaterThan(0));
      audio.room(state('day', 4), isHost: true);
      await audio.settled;
      expect(backend.rainVolume, 0);
    },
  );
  test('La météo des joueurs locaux ne lance aucun son', () async {
    final room = state('wolves', 3);
    (room['game'] as Map)['weather'] = {
      'kind': 'storm',
      'seed': 0,
      'night': 1,
      'elapsed_ms': 5000,
    };
    audio.room(room, isHost: false);
    await audio.settled;
    expect(backend.weatherCalls, isEmpty);
    expect(backend.thunders, 0);
  });

  test(
    'Un seul hurlement par ouverture, musique diminuée pendant le son',
    () async {
      audio.welcome();
      await audio.settled;
      expect(backend.calls.where((s) => s == 'wolf_howl.mp3').length, 1);
      expect(backend.bed, closeTo(audio.musicLevel * .2, .001));
      backend.completed.add(null);
      await audio.settled;
      expect(backend.bed, closeTo(audio.musicLevel, .001));
      audio.silence();
      await audio.settled;
      audio.welcome();
      await audio.settled;
      expect(backend.calls.where((s) => s == 'wolf_howl.mp3').length, 1);
    },
  );
  test(
    'Un appel unique par phase MDJ ; instantanés et réglages sans répétition',
    () async {
      audio.room(state('wolves', 3), isHost: true);
      await audio.settled;
      audio.room(state('wolves', 3), isHost: true);
      await audio.settled;
      audio.levels(music: .2);
      await audio.settled;
      expect(
        backend.calls
            .where((s) => s == 'neural/classic_male/wolves.wav')
            .length,
        1,
      );
      audio.room(state('witch', 4), isHost: true);
      await audio.settled;
      expect(backend.calls.last, 'neural/classic_male/witch.wav');
    },
  );
  test('Joueurs locaux silencieux même avec des phases secrètes', () async {
    audio.room(state('wolves', 3), isHost: false);
    await audio.settled;
    expect(backend.calls, isEmpty);
    audio.room(state('wolves', 3), isHost: true);
    await audio.settled;
    audio.room(state('wolves', 3), isHost: false);
    await audio.settled;
    expect(backend.calls.last, 'stop');
  });
  test(
    'Une transition immédiate vers un joueur annule les sons en attente',
    () async {
      audio.welcome();
      audio.room(state('wolves', 3), isHost: false);
      await audio.settled;
      expect(
        backend.calls.where((s) => s.endsWith('.mp3') || s.endsWith('.wav')),
        isEmpty,
      );
    },
  );
  test('Arrière-plan et retour ne répètent pas une narration', () async {
    audio.room(state('seer', 2), isHost: true);
    await audio.settled;
    audio.didChangeAppLifecycleState(AppLifecycleState.paused);
    await audio.settled;
    expect(backend.calls.last, 'stop');
    audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await audio.settled;
    audio.room(state('seer', 2), isHost: true);
    await audio.settled;
    expect(
      backend.calls.where((s) => s == 'neural/classic_male/seer.wav').length,
      1,
    );
  });
  test('Couper et réactiver le son ne rejoue pas l’appel', () async {
    audio.room(state('wolves', 3), isHost: true);
    await audio.settled;
    audio.levels(mute: true);
    await audio.settled;
    expect(backend.calls.last, 'stop');
    audio.levels(mute: false);
    await audio.settled;
    expect(backend.calls.last, 'music');
    expect(
      backend.calls.where((s) => s == 'neural/classic_male/wolves.wav').length,
      1,
    );
  });
  test(
    'Erreur de lecture récupérable et répétition manuelle possible',
    () async {
      backend.fail = true;
      audio.room(state('wolves', 3), isHost: true);
      await audio.settled;
      expect(audio.error, isNotNull);
      backend.fail = false;
      audio.replay();
      await audio.settled;
      expect(backend.calls.last, 'neural/classic_male/wolves.wav');
    },
  );
  test('Tous les appels déclarés sont embarqués', () {
    for (final asset in ['claw_1.wav', 'claw_2.wav']) {
      expect(
        File('assets/audio/classic/$asset').lengthSync(),
        greaterThan(1000),
      );
    }
    for (final asset in ClassicAudio.voiceAssets) {
      expect(
        File('assets/audio/classic/$asset').lengthSync(),
        greaterThan(1000),
      );
    }
    expect(
      File('assets/audio/classic/wolf_howl.mp3').lengthSync(),
      greaterThan(10000),
    );
  });
  test(
    'Griffures avant l’accueil et hurlement sans redémarrer la musique',
    () async {
      audio.opening();
      await audio.settled;
      audio.openingScratch(1);
      await audio.settled;
      audio.openingScratch(2);
      await audio.settled;
      expect(backend.calls.where((s) => s.startsWith('claw_')).toList(), [
        'claw_1.wav',
        'claw_2.wav',
      ]);
      expect(backend.calls, isNot(contains('wolf_howl.mp3')));
      audio.welcome();
      await audio.settled;
      expect(backend.calls.last, 'wolf_howl.mp3');
      expect(backend.calls.where((s) => s == 'music').length, 1);
      audio.openingScratch(1);
      await audio.settled;
      expect(backend.calls.last, 'wolf_howl.mp3');
    },
  );
  test(
    'Des appels rapides ne mettent pas en file des phases dépassées',
    () async {
      audio.room(state('seer', 2), isHost: true);
      audio.room(state('wolves', 3), isHost: true);
      audio.room(state('witch', 4), isHost: true);
      await audio.settled;
      expect(backend.calls.where((s) => s.endsWith('.wav')).toList(), [
        'neural/classic_male/witch.wav',
      ]);
    },
  );
}
